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

  # An upstream cut is the better cut, and re-cutting on every replace would churn
  # S3 and swap a deliberate cut for a generic one. The callback enqueues whenever
  # a master lands, so the job is what has to decline the work.
  test "an upload that brings its own preview is left alone" do
    attach_full_track(@song, "long_audio.mp3")   # master first,
    existing = attach_preview(@song)             # then the cut, as the API does

    GeneratePreviewJob.perform_now(@song)
    @song.reload

    assert_equal existing, @song.preview_audio.blob.id,
      "the job replaced a preview the caller supplied"
  end

  test "does nothing, quietly, when there is no full track to cut" do
    assert_nothing_raised { GeneratePreviewJob.perform_now(@song) }
    assert_not @song.reload.preview_audio.attached?
  end

  # The wire, not the cut. This job was documented as the fallback for admin and
  # browser uploads and enqueued by nothing at all, so a song uploaded through
  # MilkAdmin was saved successfully and could never be played publicly — the job
  # existed while the behaviour it promised did not.
  test "a song saved with a master and no preview enqueues the cut" do
    song = Song.new(title: "Needs a Cut", artist: artists(:first_artist))
    song.audio_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "audio.mp3",
      content_type: "audio/mpeg"
    )

    assert_enqueued_with(job: GeneratePreviewJob) { song.save! }
  end

  # Replacing a master must not leave the previous recording playing. The song is
  # edited in MilkAdmin, a new audio_file lands, the optional preview field is left
  # blank — and without this the public player keeps serving a cut of the track
  # that was replaced, with no control in the admin to remove it.
  test "replacing the master discards the preview cut from the old one" do
    old_blob_id = attach_preview(@song)          # a cut of the OLD master
    attach_full_track(@song, "audio.mp3")        # the master is replaced

    GeneratePreviewJob.perform_now(@song)
    @song.reload

    assert_not_equal old_blob_id, @song.preview_audio.blob.id,
      "the song is still serving a cut of the audio that was replaced"
    assert_nil ActiveStorage::Blob.find_by(id: old_blob_id),
      "the stale preview blob should be purged, not merely detached"
    assert @song.preview_audio.attached?, "a replacement master needs a fresh cut"
  end

  # The distinction the staleness rule turns on: equal or newer means current.
  # Age, not presence, is what decides — an upload's own cut arrives after its
  # master and must survive; an orphaned cut from a replaced master must not.
  test "a preview is considered stale only when it predates the master" do
    song = Song.new(title: "Order Matters", artist: artists(:first_artist))
    song.audio_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "master.mp3",
      content_type: "audio/mpeg"
    )
    song.preview_audio.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "cut.mp3",
      content_type: "audio/mpeg"
    )
    song.save!

    assert_operator song.preview_audio.blob.created_at, :>=, song.audio_file.blob.created_at,
      "the API/upload order attaches the master first, so its own cut never predates it"
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
