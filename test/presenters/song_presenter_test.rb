# frozen_string_literal: true

require "test_helper"

class SongPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  setup do
    ActiveStorage::Current.url_options = { host: "localhost", port: 3000, protocol: "http" }
    @song = songs(:one)
    # Ensure attachments are associated for the test
    @song.image.attach(io: File.open(Rails.root.join("test/fixtures/files/cover.jpg")), filename: "cover.jpg", content_type: "image/jpeg")
    @song.audio_file.attach(io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")), filename: "full_track.mp3", content_type: "audio/mpeg")
    @song.preview_audio.attach(io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")), filename: "preview.mp3", content_type: "audio/mpeg")
  end

  test "#to_song_hash formats a complete song correctly" do
    freeze_time do
      presenter = SongPresenter.new(@song)
      hash = presenter.to_song_hash

      assert_equal @song.id, hash[:id]
      assert_equal @song.title, hash[:title]
      assert_equal @song.artist.name, hash[:artist]
      assert_not_nil hash[:url]
      assert_not_nil hash[:banner]
      assert_not_nil hash[:grid_banner]
      assert_not_nil hash[:bannerMobile]

      # Check that it includes correct url formats
      # assert_equal @song.audio_file.url, hash[:url]
      assert_equal rails_blob_url(@song.image), hash[:banner]
    end
  end

  test "#to_song_hash handles songs without attachments" do
    song_without_attachments = songs(:two)
    # Ensure the fixture is clean for this test
    song_without_attachments.image.detach
    song_without_attachments.audio_file.detach
    song_without_attachments.preview_audio.detach

    presenter = SongPresenter.new(song_without_attachments)
    hash = presenter.to_song_hash

    assert_equal song_without_attachments.id, hash[:id]
    assert_nil hash[:url]
    assert_nil hash[:banner]
    assert_nil hash[:grid_banner]
    assert_nil hash[:bannerMobile]
    assert_equal 0, hash[:duration]
  end

  # The presenter is what the public player renders, so the URL it emits has to
  # be the preview's. Asserting only "not nil" would pass on the full track too.
  # Compared by filename because two calls to `.url` mint different signed
  # params — the signature carries a fresh expiry.
  test "#to_song_hash serves the preview URL, never the full track" do
    hash = SongPresenter.new(@song).to_song_hash

    assert_match(/preview\.mp3/, hash[:url])
    assert_no_match(/full_track\.mp3/, hash[:url],
      "the full-track URL must never be what the public player is handed")
  end

  test "#to_song_hash includes duration when available" do
    # The metadata worker might not run in test, so we simulate the metadata
    @song.preview_audio.metadata[:duration] = 123.45
    @song.preview_audio.save!

    presenter = SongPresenter.new(@song)
    hash = presenter.to_song_hash

    assert_equal 123.45, hash[:duration]
  end

  # An attached preview with no analysed metadata still has to report a length,
  # or the player renders a scrubber with no end. The cut window is the honest
  # fallback: the file is a 30-second cut by construction.
  test "#to_song_hash falls back to the cut window when the preview is unanalysed" do
    @song.preview_audio.metadata.delete(:duration)
    @song.preview_audio.save!

    hash = SongPresenter.new(@song).to_song_hash

    assert_equal Zuke::PreviewCutter::PREVIEW_SECONDS, hash[:duration]
  end

  # The waveform has to describe the file that is actually playing. Generating
  # the preview's waveform onto the full track's attachment was a real proposal
  # once, and it would make the public scrubber lie.
  test "#to_song_hash uses the preview waveform, not the full track's" do
    @song.waveform_data.attach(
      io: StringIO.new('{"full": true}'), filename: "full_waveform.json", content_type: "application/json"
    )
    @song.preview_waveform_data.attach(
      io: StringIO.new('{"preview": true}'), filename: "preview_waveform.json", content_type: "application/json"
    )

    hash = SongPresenter.new(@song).to_song_hash

    assert_match(/preview_waveform\.json/, hash[:waveformUrl])
    assert_no_match(/full_waveform\.json/, hash[:waveformUrl])
  end
end
