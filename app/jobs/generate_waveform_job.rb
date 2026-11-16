# frozen_string_literal: true

# Builds a JSON waveform for one of a Song's audio attachments.
#
# Parameterised by source because a song has two pieces of audio — the full track
# and the 30-second preview — and one waveform JSON cannot describe both. The
# preview's waveform goes to +preview_waveform_data+, never onto the full track's,
# or the public scrubber would describe a file it is not playing.
class GenerateWaveformJob < ApplicationJob
  queue_as :default

  # source attachment name => where the generated JSON is attached
  SOURCES = {
    "audio_file" => :waveform_data,
    "preview_audio" => :preview_waveform_data
  }.freeze

  # @param song [Song]
  # @param source [String] "audio_file" (default) or "preview_audio"
  def perform(song, source = "audio_file")
    target = SOURCES.fetch(source) { raise ArgumentError, "unknown waveform source: #{source.inspect}" }
    audio = song.public_send(source)

    unless audio.attached?
      Rails.logger.info("GenerateWaveformJob: Song ##{song.id} has no #{source}; nothing to do")
      return
    end

    # Purge any old waveform so the JSON always describes the current audio.
    song.public_send(target).purge if song.public_send(target).attached?

    # Active Storage's #open downloads the file to a temporary location on disk,
    # which is required for command-line tools like audiowaveform. The block
    # ensures the temp file is removed afterward.
    audio.blob.open do |temp_audio_file|
      # A unique temporary path avoids two jobs racing on the same output file.
      output_path = Rails.root.join("tmp", "#{song.id}-#{SecureRandom.uuid}_waveform.json")

      # Shellwords prevents injection. -b 8 keeps the file small, which is plenty
      # for a visualisation.
      command = "audiowaveform -i #{Shellwords.escape(temp_audio_file.path)} " \
                "-o #{Shellwords.escape(output_path.to_s)} -b 8"

      system(command)

      if File.exist?(output_path)
        song.public_send(target).attach(
          io: File.open(output_path),
          filename: "#{song.title.parameterize}_#{source}_waveform.json",
          content_type: "application/json"
        )
      else
        Rails.logger.error "Waveform generation failed for Song ##{song.id} (#{source}). Command: #{command}"
      end
    ensure
      # Always clean up, even if the command failed.
      File.delete(output_path) if File.exist?(output_path)
    end
  end
end
