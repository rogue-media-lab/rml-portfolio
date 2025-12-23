# frozen_string_literal: true

require "test_helper"

class SongPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  setup do
    ActiveStorage::Current.url_options = { host: "localhost", port: 3000, protocol: "http" }
    @song = songs(:one)
    # Ensure attachments are associated for the test
    @song.image.attach(io: File.open(Rails.root.join("test/fixtures/files/cover.jpg")), filename: "cover.jpg", content_type: "image/jpeg")
    @song.audio_file.attach(io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")), filename: "audio.mp3", content_type: "audio/mp3")
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

    presenter = SongPresenter.new(song_without_attachments)
    hash = presenter.to_song_hash

    assert_equal song_without_attachments.id, hash[:id]
    assert_nil hash[:url]
    assert_nil hash[:banner]
    assert_nil hash[:grid_banner]
    assert_nil hash[:bannerMobile]
    assert_equal 0, hash[:duration]
  end

  test "#to_song_hash includes duration when available" do
    # The metadata worker might not run in test, so we simulate the metadata
    @song.audio_file.metadata[:duration] = 123.45
    @song.audio_file.save!

    presenter = SongPresenter.new(@song)
    hash = presenter.to_song_hash

    assert_equal 123.45, hash[:duration]
  end
end
