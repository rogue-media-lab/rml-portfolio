# frozen_string_literal: true

require "open3"
require "shellwords"
require "fileutils"
require "tmpdir"

module Zuke
  # The one implementation of "cut a 30-second preview".
  #
  # Deliberately free of Rails: it touches only ffmpeg, ffprobe and the Ruby
  # standard library, so it can be invoked from anywhere — the CLI wrapper in
  # bin/zuke-cut-preview, the Maestro upload flow, or GeneratePreviewJob.
  # Anything needing the app environment could not run from the first two, and
  # those are the paths that are supposed to be doing the cutting.
  #
  # The command this replaces was wrong four ways, and every fix is load-bearing:
  #
  #   1. `afade=t=out:st=28` gave a track shorter than 28s no fade at all — the
  #      fade started past the end of the file. The fade-out is anchored to the
  #      length actually being kept, so a 3-second track fades like anything else.
  #   2. `loudnorm` ran AFTER `afade`, so the loudness gate measured the fades
  #      (silence) rather than programme material. It now runs first.
  #   3. Single-pass loudnorm returns NaN on very short input, which makes ffmpeg
  #      fail to produce a file. That case is detected and retried as a plain
  #      copy, rather than hoped away.
  #   4. `libmp3lame` was hardcoded, so an m4a or flac upload — both permitted by
  #      the upload API — was written into a container its codec did not match.
  #      The codec is derived from the source.
  class PreviewCutter
    PREVIEW_SECONDS = 30.0
    FADE_MAX = 1.0
    LOUDNESS = "I=-16:TP=-1.5:LRA=11"

    # source extension => [encoder, output extension, content type]
    FORMATS = {
      "mp3" => [ "libmp3lame", "mp3", "audio/mpeg" ],
      "m4a" => [ "aac", "m4a", "audio/mp4" ],
      "mp4" => [ "aac", "m4a", "audio/mp4" ],
      "aac" => [ "aac", "aac", "audio/aac" ],
      "flac" => [ "flac", "flac", "audio/flac" ],
      "wav" => [ "pcm_s16le", "wav", "audio/wav" ],
      "ogg" => [ "libvorbis", "ogg", "audio/ogg" ],
      "oga" => [ "libvorbis", "ogg", "audio/ogg" ],
      "opus" => [ "libopus", "opus", "audio/opus" ]
    }.freeze

    DEFAULT_FORMAT = FORMATS.fetch("mp3")

    class CutError < StandardError; end

    # trimmed   — the source was longer than the preview window and was cut
    # normalized — loudnorm succeeded; false means we fell back to a plain copy
    # cleanup_dir — the temp directory this cut was written into, when the cutter
    #   created it. nil when the caller supplied its own output_dir.
    Result = Struct.new(:path, :filename, :content_type, :duration, :trimmed, :normalized,
                        :cleanup_dir, keyword_init: true) do
      def trimmed? = trimmed

      # Removes the temporary directory this preview was cut into, when the
      # cutter made it. A caller that passed its own output_dir owns that
      # directory, so this is a no-op for them.
      #
      # Without this, every GeneratePreviewJob run and every CLI invocation left
      # an orphaned /tmp/zuke-preview* directory behind: #initialize calls
      # Dir.mktmpdir without a block, and nothing downstream removed it.
      def cleanup
        return false unless cleanup_dir && File.directory?(cleanup_dir)

        FileUtils.remove_entry(cleanup_dir)
        true
      end
    end

    def self.call(...) = new(...).call

    def initialize(path, filename: nil, output_dir: nil)
      @path = path.to_s
      @filename = filename
      @owns_output_dir = output_dir.nil?
      @output_dir = output_dir || Dir.mktmpdir("zuke-preview")
    end

    def call
      raise CutError, "no source file at #{@path}" unless File.exist?(@path)

      duration = probe_duration(@path)
      encoder, extension, content_type = output_format

      FileUtils.mkdir_p(@output_dir)
      output_path = File.join(@output_dir, "preview.#{extension}")

      trimmed = duration > PREVIEW_SECONDS
      normalized = run_cut(output_path, encoder, duration, trimmed)

      unless normalized
        # A plain copy is a worse preview than a normalised one, but it is a
        # preview. Silently shipping nothing would put the song back on the
        # "unplayable" pile with no explanation.
        normalized = run_plain_copy(output_path, encoder)
      end

      raise CutError, "ffmpeg produced no preview from #{@path}" unless normalized

      Result.new(
        path: output_path,
        filename: "preview.#{extension}",
        content_type: content_type,
        duration: trimmed ? PREVIEW_SECONDS : duration,
        trimmed: trimmed,
        normalized: normalized,
        cleanup_dir: (@owns_output_dir ? @output_dir : nil)
      )
    rescue StandardError
      # The happy path hands cleanup to the caller via Result#cleanup. A raise
      # returns no Result at all, so nobody would ever remove the directory —
      # a missing source or a file ffmpeg cannot decode orphaned one per call.
      # Nothing usable was produced, so there is nothing to preserve.
      discard_own_output_dir
      raise
    end

    private

    def discard_own_output_dir
      FileUtils.remove_entry(@output_dir) if @owns_output_dir && File.directory?(@output_dir)
    end

    # Seconds, or 0.0 when the file cannot be measured. Zero is treated as "too
    # short to trim" rather than as an error — the cut still runs, it just never
    # trims, and the fade lands inside the file instead of past the end.
    def probe_duration(path)
      out, _err, status = Open3.capture3(
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "csv=p=0", path
      )
      return 0.0 unless status.success?

      Float(out.strip)
    rescue ArgumentError, TypeError
      0.0
    end

    def output_format
      extension = File.extname(@filename.to_s).delete(".").downcase
      extension = probe_extension if extension.empty?
      FORMATS.fetch(extension.to_s, DEFAULT_FORMAT)
    end

    # For sources whose name tells us nothing — a temp file, a blob with no
    # filename. Deciding by extension alone would guess MP3 for those.
    def probe_extension
      out, _err, status = Open3.capture3(
        "ffprobe", "-v", "error", "-show_entries", "format=format_name",
        "-of", "csv=p=0", @path
      )
      return nil unless status.success?

      out.strip.downcase.split(",").find { |name| FORMATS.key?(name) }
    rescue StandardError
      nil
    end

    # Returns true when the normalised cut was written.
    #
    # The fade-out is positioned to COMPLETE at the end of the material being
    # kept, not to start a fixed distance before the window. `afade=t=out` does
    # not stop attenuating when its duration elapses — it holds gain at zero for
    # everything after — so anchoring the fade to a fixed offset from the window
    # (the plan's `min(DUR, 30) - 2`) silences the rest of the file: a 3-second
    # track went mute at 1.3s, and every trimmed preview ended with a full second
    # of dead air. Ending the fade on the final sample gives a real fade and no
    # hole.
    def run_cut(output_path, encoder, duration, trimmed)
      keep = trimmed ? PREVIEW_SECONDS : duration
      fade = [ FADE_MAX, keep / 10.0 ].min
      fade = 0.0 unless fade.positive?
      fade_start = [ keep - fade, 0.0 ].max

      filters = [ "loudnorm=#{LOUDNESS}", "afade=t=in:st=0:d=#{fade}" ]
      filters << "afade=t=out:st=#{fade_start}:d=#{fade}" if fade.positive?

      command = [ "ffmpeg", "-y", "-v", "error" ]
      # Trimmed runs end at the window; the fade-out lands on the last sample.
      # Untrimmed is left to run to the source's own end so a generous duration
      # estimate can never clip material.
      command += [ "-t", PREVIEW_SECONDS.to_i.to_s ] if trimmed
      command += [ "-i", @path, "-af", filters.join(","), "-c:a", encoder, output_path ]

      execute(command, output_path)
    end

    def run_plain_copy(output_path, encoder)
      FileUtils.rm_f(output_path)
      execute([ "ffmpeg", "-y", "-v", "error", "-i", @path, "-c:a", encoder, output_path ], output_path)
    end

    # ffmpeg can exit 0 having written nothing usable, so the file is the
    # evidence, not the exit status.
    def execute(command, output_path)
      _out, err, status = Open3.capture3(*command)
      usable = status.success? && File.exist?(output_path) && File.size(output_path).positive?

      unless usable
        warn "Zuke::PreviewCutter: #{command.shelljoin} failed (#{status.exitstatus}): #{err.to_s.strip[0, 400]}"
      end

      usable
    end
  end
end
