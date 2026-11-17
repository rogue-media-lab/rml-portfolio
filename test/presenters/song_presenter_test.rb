# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

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

  # --- the listener decides what is served --------------------------------------
  #
  # Same song, different callers. Pinning only the preview would pass even if the
  # listener were ignored entirely, so every case is asserted from both sides.

  test "#to_song_hash serves the master to a listener who owns the song" do
    owner = User.create!(email: "owner@example.com", password: "password123")
    @song.users << owner
    @song.waveform_data.attach(
      io: StringIO.new('{"full": true}'), filename: "full_waveform.json", content_type: "application/json"
    )

    hash = SongPresenter.new(@song, listener: owner).to_song_hash

    assert_match(/full_track\.mp3/, hash[:url])
    assert_no_match(/preview\.mp3/, hash[:url])

    # The waveform has to follow the audio, or the scrubber describes a file that is
    # not the one playing — the same reason the per-file waveform split exists.
    assert_match(/full_waveform\.json/, hash[:waveformUrl])
    assert_no_match(/preview_waveform\.json/, hash[:waveformUrl])
  end

  test "#to_song_hash serves the master to an account granted can_download" do
    entitled = User.create!(email: "entitled@example.com", password: "password123")
    entitled.update!(can_download: true)

    hash = SongPresenter.new(@song, listener: entitled).to_song_hash

    assert_match(/full_track\.mp3/, hash[:url])
  end

  # Signing up is not a licence to the full track. This is the same rule the download
  # endpoints ask, so the two cannot disagree about who may have the master.
  test "#to_song_hash still serves the preview to a signed-in listener with no right" do
    stranger = User.create!(email: "stranger@example.com", password: "password123")

    hash = SongPresenter.new(@song, listener: stranger).to_song_hash

    assert_match(/preview\.mp3/, hash[:url])
    assert_no_match(/full_track\.mp3/, hash[:url])
  end

  # An entitled listener on a song whose master was never attached must not get a nil
  # URL — the preview is the only audio there is, and a nil url is a dead play button.
  test "#to_song_hash falls back to the preview when the master is not attached" do
    @song.audio_file.detach
    owner = User.create!(email: "owner-fallback@example.com", password: "password123")
    @song.users << owner

    hash = SongPresenter.new(@song, listener: owner).to_song_hash

    assert_match(/preview\.mp3/, hash[:url])
  end

  # Hearing in full and downloading share one rule deliberately. If the delegation ever
  # broke — a second copy of the condition inside downloadable_by? — the two could drift,
  # and someone could end up able to take a copy of something they cannot play, or the
  # reverse.
  test "downloadable_by? delegates to full_audio_for? instead of restating the rule" do
    entitled = User.create!(email: "shared-rule@example.com", password: "password123")
    entitled.update!(can_download: true)

    assert @song.full_audio_for?(entitled)
    assert_not @song.full_audio_for?(nil), "anonymous callers get nothing"

    # Asserting the two merely agree would pass with the condition duplicated, so the
    # rule itself is stubbed: whatever it answers is what downloadable_by? must answer.
    @song.stub(:full_audio_for?, true) do
      assert @song.downloadable_by?(entitled),
        "downloadable_by? must ask full_audio_for?, or the two can drift"
    end

    @song.stub(:full_audio_for?, false) do
      assert_not @song.downloadable_by?(entitled)
    end
  end

  # The admin curates these songs and the previews the public hears, so the whole
  # collection is theirs to hear in full.
  test "#to_song_hash serves the master to a librarian" do
    hash = SongPresenter.new(@song, listener: milk_admins(:admin_one)).to_song_hash

    assert_match(/full_track\.mp3/, hash[:url])
    assert_no_match(/preview\.mp3/, hash[:url])
  end
end
