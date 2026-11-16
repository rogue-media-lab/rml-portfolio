# frozen_string_literal: true

require "test_helper"

# The fallback cut. This job is deliberately NOT the primary path — Maestro cuts
# upstream — but when the browser or MilkAdmin uploads a bare track, this is all
# that stands between the song and having no preview at all.
class GeneratePreviewJobTest < ActiveJob::TestCase
  setup do
    @song = songs(:one)
    @song.preview_audio.purge if @song.preview_audio.attached?
    @song.audio_file.purge if @song.audio_file.attached?
  end

  test "cuts a preview from the full track" do
    attach_full_track(@song, "audio.mp3")

    GeneratePreviewJob.perform_now(@song)
    @song.reload

    assert @song.preview_audio.attached?, "the fallback cut produced no preview"
    assert @song.playable?, "a song with a preview must be playable"
    assert_not_equal @song.audio_file.blob.id, @song.preview_audio.blob.id,
      "the preview must be its own blob, not the full track"
  end

  test "records the real duration so the player need not analyse the file" do
    attach_full_track(@song, "audio.mp3")

    GeneratePreviewJob.perform_now(@song)
    @song.reload

    assert_in_delta 3.03, @song.preview_audio.metadata["duration"].to_f, 0.5
  end

  # An upstream cut is the better cut, and re-cutting on every save would churn
  # S3 for nothing.
  test "never overwrites a preview that is already attached" do
    existing = attach_preview(@song)
    attach_full_track(@song, "long_audio.mp3")

    GeneratePreviewJob.perform_now(@song)
    @song.reload

    assert_equal existing, @song.preview_audio.blob.id,
      "the job replaced a preview that was already there"
  end

  test "does nothing, quietly, when there is no full track to cut" do
    assert_nothing_raised { GeneratePreviewJob.perform_now(@song) }
    assert_not @song.reload.preview_audio.attached?
  end

  private

  def attach_full_track(song, fixture)
    song.audio_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files", fixture)),
      filename: fixture,
      content_type: "audio/mpeg"
    )
  end

  def attach_preview(song)
    song.preview_audio.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "existing_preview.mp3",
      content_type: "audio/mpeg"
    )
    song.reload.preview_audio.blob.id
  end
end
