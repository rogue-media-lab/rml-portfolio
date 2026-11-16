require "test_helper"
require "minitest/mock"

class GenerateWaveformJobTest < ActiveJob::TestCase
  setup do
    @song = songs(:one)
    # Ensure no attachments exist initially to start clean
    @song.waveform_data.purge if @song.waveform_data.attached?
    @song.audio_file.purge if @song.audio_file.attached?

    # Attach a dummy audio file
    @song.audio_file.attach(
      io: StringIO.new("dummy audio content"),
      filename: "test.mp3",
      content_type: "audio/mpeg"
    )
  end

  test "job is enqueued correctly" do
    assert_enqueued_with(job: GenerateWaveformJob, args: [ @song ]) do
      GenerateWaveformJob.perform_later(@song)
    end
  end

  test "perform executes audiowaveform and attaches json" do
    # We patch the system method on the job instance to avoid external calls
    GenerateWaveformJob.class_eval do
      alias_method :original_system, :system
      def system(cmd)
        # Mock the side effect: create the expected output file
        # Command looks like: audiowaveform -i ... -o /path/to/output.json ...
        output_path = cmd.split("-o ")[1].split(" ")[0]
        File.write(output_path, '{"version": 2, "channels": 1, "data": [0, 128, 255]}')
        true
      end
    end

    begin
      perform_enqueued_jobs do
        GenerateWaveformJob.perform_later(@song)
      end

      @song.reload
      assert @song.waveform_data.attached?, "Waveform data should be attached after job runs"
      assert_equal "application/json", @song.waveform_data.content_type
      assert_match(/_waveform\.json/, @song.waveform_data.filename.to_s)
    ensure
      # Restore original system method to avoid polluting other tests
      GenerateWaveformJob.class_eval do
        alias_method :system, :original_system
      end
    end
  end

  # The parameterisation is the whole point of this job: a song has two audio
  # files and one JSON cannot describe both. Nothing exercised the preview branch,
  # so a regression there — the preview's waveform landing on the full track's
  # attachment — would have gone unnoticed.
  test "the preview source writes preview_waveform_data, not waveform_data" do
    @song.preview_audio.attach(
      io: StringIO.new("dummy preview audio"),
      filename: "preview.mp3",
      content_type: "audio/mpeg"
    )
    @song.preview_waveform_data.purge if @song.preview_waveform_data.attached?

    GenerateWaveformJob.class_eval do
      alias_method :original_system, :system
      def system(cmd)
        output_path = cmd.split("-o ")[1].split(" ")[0]
        File.write(output_path, '{"version": 2, "channels": 1, "data": [0, 128, 255]}')
        true
      end
    end

    begin
      GenerateWaveformJob.perform_now(@song, "preview_audio")
      @song.reload

      assert @song.preview_waveform_data.attached?,
        "preview_waveform_data was not attached"
      assert_equal "application/json", @song.preview_waveform_data.content_type
      assert_match(/_preview_audio_waveform\.json/, @song.preview_waveform_data.filename.to_s)
      assert_not @song.waveform_data.attached?,
        "the preview's waveform landed on the full track's attachment"
    ensure
      GenerateWaveformJob.class_eval do
        alias_method :system, :original_system
      end
    end
  end

  test "an unknown source is rejected rather than silently doing nothing" do
    assert_raises(ArgumentError) { GenerateWaveformJob.perform_now(@song, "banner_video") }
  end
end
