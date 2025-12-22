# frozen_string_literal: true

# The GenerateWaveformJob is responsible for creating a JSON waveform file from a Song's attached audio file.
# It is designed to be enqueued by an after_commit hook on the Song model, ensuring it only runs when
# an audio file has been newly attached or changed.
class GenerateWaveformJob < ApplicationJob
  queue_as :default

  # The main logic for generating the waveform.
  def perform(song)
    # Ensure the song has an audio file attached before proceeding.
    return unless song.audio_file.attached?

    # Purge any old waveform data to ensure a fresh generation. This is a safeguard; the model's callback
    # should prevent this job from running if the audio hasn't changed.
    song.waveform_data.purge if song.waveform_data.attached?

    # Active Storage's #open method downloads the file to a temporary location on disk, which is required
    # for command-line tools like audiowaveform. The block ensures the temp file is removed afterward.
    song.audio_file.blob.open do |temp_audio_file|
      # Define a unique temporary path for the JSON output to avoid race conditions.
      output_path = Rails.root.join("tmp", "#{song.id}-#{SecureRandom.uuid}_waveform.json")

      # Construct the shell command for audiowaveform using Shellwords to prevent injection vulnerabilities.
      # Options:
      # -i: input file
      # -o: output file
      # -b 8: bit depth of 8 for a smaller file size, which is sufficient for visualization.
      command = "audiowaveform -i #{Shellwords.escape(temp_audio_file.path)} -o #{Shellwords.escape(output_path)} -b 8"

      # Execute the command.
      system(command)

      # After execution, check if the output file was created successfully.
      if File.exist?(output_path)
        # If successful, attach the generated JSON file to the song model with a descriptive name.
        song.waveform_data.attach(
          io: File.open(output_path),
          filename: "#{song.title.parameterize}_waveform.json",
          content_type: "application/json"
        )
      else
        # If the command failed for any reason, log an error for debugging purposes.
        Rails.logger.error "Waveform generation failed for Song ##{song.id}. Command: #{command}"
      end
    ensure
      # Ensure the temporary JSON file is always deleted, even if an error occurred during processing.
      File.delete(output_path) if File.exist?(output_path)
    end
  end
end
