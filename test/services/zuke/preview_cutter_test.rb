# frozen_string_literal: true

require "test_helper"
require "open3"

# The cutter is the one place a preview is made, and every one of the four bugs
# it replaces would have shipped silently — a 3-second track with no fade looks
# fine, and a flac written as mp3 still plays in some players. So these tests
# read the produced file rather than trusting the exit status.
class Zuke::PreviewCutterTest < ActiveSupport::TestCase
  FIXTURES = Rails.root.join("test/fixtures/files")

  # 3s, 35s, 3s flac, 40s m4a — real audio, unlike the 0-byte placeholders this
  # fixture dir used to hold.
  SHORT = FIXTURES.join("audio.mp3").to_s
  LONG = FIXTURES.join("long_audio.mp3").to_s
  FLAC = FIXTURES.join("tone.flac").to_s
  M4A = FIXTURES.join("long_tone.m4a").to_s

  setup do
    @tmpdir = Dir.mktmpdir("preview-cutter-test")
  end

  teardown do
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.directory?(@tmpdir)
  end

  test "cuts a 35-second source down to the 30-second window" do
    result = Zuke::PreviewCutter.call(LONG, filename: "long_audio.mp3", output_dir: @tmpdir)

    assert result.trimmed?, "a 35s source should have been trimmed"
    assert File.exist?(result.path)
    assert_operator File.size(result.path), :>, 0
    assert_in_delta 30.0, duration_of(result.path), 0.5,
      "the cut must land on the preview window"
  end

  test "leaves a source shorter than the window whole" do
    result = Zuke::PreviewCutter.call(SHORT, filename: "audio.mp3", output_dir: @tmpdir)

    assert_not result.trimmed?, "a 3s source is already a preview"
    assert_in_delta 3.03, duration_of(result.path), 0.5,
      "a short source must not be padded or cut to 30s"
  end

  # Bug #1, and a second one found while testing it. `afade=t=out` does not stop
  # attenuating when its duration elapses — it holds gain at zero for the rest of
  # the stream. Anchoring the fade to a fixed offset from the window (the plan's
  # `min(DUR, 30) - 2`) therefore muted everything after 1.3s of a 3-second track.
  # For a short source the fade must land on the final sample, leaving the middle
  # untouched; this test measures both halves of that.
  test "a short track keeps its body and fades only at the end" do
    result = Zuke::PreviewCutter.call(SHORT, filename: "audio.mp3", output_dir: @tmpdir)

    body = mean_volume_db(result.path, at: 2.0, seconds: 0.4)
    fade = mean_volume_db(result.path, at: 2.9, seconds: 0.12)

    assert_operator fade, :<, body - 8,
      "the end of a short track (#{fade} dB) should be fading against its body " \
      "(#{body} dB) — equal levels mean no fade was applied"
    assert_operator body, :>, -30,
      "the body of a short track went silent (#{body} dB): the fade-out is " \
      "attenuating past its own duration instead of ending on the last sample"
  end

  # The trimmed case has the same failure mode: a fade anchored 2s before the
  # window ends leaves a hole of dead air before the cut.
  test "a trimmed preview fades to silence without a hole before the cut" do
    result = Zuke::PreviewCutter.call(LONG, filename: "long_audio.mp3", output_dir: @tmpdir)

    body = mean_volume_db(result.path, at: 5.0, seconds: 1.0)
    just_before_the_cut = mean_volume_db(result.path, at: 27.0, seconds: 0.5)
    tail = mean_volume_db(result.path, at: 29.85, seconds: 0.15)

    assert_operator tail, :<, body - 12,
      "the last of the preview (#{tail} dB) should be well below the body " \
      "(#{body} dB) — a hard chop means the fade-out is not running"
    assert_operator just_before_the_cut, :>, body - 4,
      "the preview went quiet early (#{just_before_the_cut} dB at 27s against " \
      "a body of #{body} dB) — dead air before the cut"
  end

  # Bug #4. An m4a or flac source written with libmp3lame is a file whose
  # container and codec disagree.
  test "the output codec follows the source, not a hardcoded mp3" do
    mp3 = Zuke::PreviewCutter.call(LONG, filename: "long_audio.mp3", output_dir: @tmpdir)
    assert_equal "mp3", audio_codec(mp3.path)

    flac = Zuke::PreviewCutter.call(FLAC, filename: "tone.flac", output_dir: @tmpdir)
    assert_equal "flac", audio_codec(flac.path)
    assert_equal "flac", flac.filename.split(".").last
    assert_equal "audio/flac", flac.content_type

    m4a = Zuke::PreviewCutter.call(M4A, filename: "long_tone.m4a", output_dir: @tmpdir)
    assert_equal "aac", audio_codec(m4a.path)
    assert_equal "audio/mp4", m4a.content_type
  end

  # Blob temp files arrive with no useful name. Falling back to MP3 there would
  # write a flac stream into an .mp3 container.
  test "identifies the format by probing when the filename says nothing" do
    anonymous = File.join(@tmpdir, "blob")
    FileUtils.cp(FLAC, anonymous)

    result = Zuke::PreviewCutter.call(anonymous, filename: nil, output_dir: @tmpdir)

    assert_equal "flac", audio_codec(result.path)
  end

  test "reports the duration it produced, so the player need not analyse the file" do
    result = Zuke::PreviewCutter.call(LONG, filename: "long_audio.mp3", output_dir: @tmpdir)

    assert_in_delta duration_of(result.path), result.duration, 0.5
  end

  test "raises rather than returning a path to nothing" do
    assert_raises(Zuke::PreviewCutter::CutError) do
      Zuke::PreviewCutter.call(File.join(@tmpdir, "does-not-exist.mp3"), output_dir: @tmpdir)
    end
  end

  # An 0.08s source is where single-pass loudnorm is known to return NaN. The
  # job must still come back with a playable file rather than an empty path.
  test "an extremely short source still produces a file" do
    tiny = File.join(@tmpdir, "tiny.mp3")
    system("ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=0.08",
           "-c:a", "libmp3lame", tiny, exception: true)

    result = Zuke::PreviewCutter.call(tiny, filename: "tiny.mp3", output_dir: @tmpdir)

    assert File.exist?(result.path)
    assert_operator File.size(result.path), :>, 0
  end

  # The CLI is what Maestro actually calls, so it gets exercised rather than
  # assumed. It runs on plain Ruby with no Rails boot — the whole reason the
  # cutter has no app dependencies.
  test "bin/zuke-cut-preview writes to the path it is given and echoes it" do
    destination = File.join(@tmpdir, "maestro-preview.mp3")

    out, err, status = Open3.capture3(
      Rails.root.join("bin/zuke-cut-preview").to_s, LONG, destination
    )

    assert status.success?, "CLI failed: #{err}"
    assert_equal destination, out.strip
    assert File.exist?(destination), "CLI reported a path it did not write"
    assert_in_delta 30.0, duration_of(destination), 0.5
  end

  test "bin/zuke-cut-preview exits non-zero on a missing source" do
    _out, err, status = Open3.capture3(
      Rails.root.join("bin/zuke-cut-preview").to_s, File.join(@tmpdir, "nope.mp3")
    )

    assert_not status.success?
    assert_match(/no such file/, err)
  end

  # The cutter creates its own temp directory when the caller does not pass one,
  # so removing it is the cutter's job. It was nobody's, and every job run and
  # CLI invocation orphaned a /tmp/zuke-preview* tree.
  test "removes the temporary directory it created" do
    result = Zuke::PreviewCutter.call(SHORT, filename: "audio.mp3")
    dir = result.cleanup_dir

    assert dir, "the cutter should report the directory it created"
    assert File.directory?(dir), "the cut should exist before cleanup"
    assert result.cleanup, "cleanup should report that it removed something"
    assert_not File.exist?(dir), "the temp directory outlived the cut"
  end

  test "leaves a caller-supplied output directory alone" do
    result = Zuke::PreviewCutter.call(SHORT, filename: "audio.mp3", output_dir: @tmpdir)

    assert_nil result.cleanup_dir, "the caller's directory is not ours to remove"
    assert_not result.cleanup
    assert File.exist?(result.path), "the caller's preview must survive cleanup"
  end

  # The usage line promises ./preview.mp3 with no destination. The CLI left the
  # file in the cutter's temp directory instead and printed that path.
  test "bin/zuke-cut-preview with no destination writes into the current directory" do
    out, err, status = Open3.capture3(
      Rails.root.join("bin/zuke-cut-preview").to_s, SHORT, chdir: @tmpdir
    )

    assert status.success?, "CLI failed: #{err}"
    written = out.strip
    assert_equal File.join(@tmpdir, "preview.mp3"), written,
      "the CLI should report an absolute path in the working directory"
    assert File.exist?(written), "the CLI reported a path it did not write"
  end

  private

  def duration_of(path)
    probe(path, "format=duration").to_f
  end

  def audio_codec(path)
    probe(path, "stream=codec_name")
  end

  def probe(path, entries)
    out, _err, status = Open3.capture3("ffprobe", "-v", "error", "-show_entries", entries, "-of", "csv=p=0", path)
    assert status.success?, "ffprobe failed on #{path}"
    out.strip.lines.first.to_s.strip
  end

  # ffmpeg's volumedetect prints its histogram to stderr. Reading it is how these
  # tests check a fade happened without decoding the samples by hand.
  def mean_volume_db(path, at:, seconds:)
    _out, err, status = Open3.capture3(
      "ffmpeg", "-hide_banner", "-ss", at.to_s, "-t", seconds.to_s, "-i", path,
      "-af", "volumedetect", "-f", "null", "-"
    )
    assert status.success?, "volumedetect failed on #{path}"

    match = err.match(/mean_volume:\s*(-?[\d.]+|-inf)\s*dB/)
    assert match, "no mean_volume in volumedetect output:\n#{err}"

    match[1] == "-inf" ? -100.0 : match[1].to_f
  end
end
