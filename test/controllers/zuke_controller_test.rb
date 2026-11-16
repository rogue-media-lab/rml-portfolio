# frozen_string_literal: true

require "test_helper"

class ZukeControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @milk_admin = milk_admins(:admin_one)
    @song_one = songs(:one)
    @song_two = songs(:two)
    @rock_genre = genres(:rock)
    @pop_genre = genres(:pop)
  end

  test "should get index" do
    get zuke_index_url
    assert_response :success
  end

  test "guest should see all public songs in music" do
    get music_list_zuke_index_url
    assert_response :success

    loaded_songs = assigns(:songs_for_display)
    assert_not_nil loaded_songs, "Should assign @songs_for_display"

    assert_equal 27, loaded_songs.size, "Should load all 27 public songs"
  end

  test "milk admin should see all songs in music" do
    sign_in @milk_admin

    get music_list_zuke_index_url
    assert_response :success

    loaded_songs = assigns(:songs_for_display)
    assert_not_nil loaded_songs

    assert_equal 27, loaded_songs.size, "Should load all 27 songs"
  end

  test "genres action should be performant and limit songs" do
    get music_genres_zuke_index_url
    assert_response :success

    grouped_genres = assigns(:grouped_genres)
    assert_not_nil grouped_genres
    assert_equal 2, grouped_genres.size # Rock and Pop

    # Rock genre has 25 songs in fixtures + song 'one' = 26 songs
    # The query should limit this to 20
    assert_equal 20, grouped_genres[@rock_genre].size

    # Pop genre has 1 song in fixtures
    assert_equal 1, grouped_genres[@pop_genre].size
  end

  # GET /zuke/albums rendered "zuke/turbo_frames/albums", a partial that did not
  # exist, so the route returned a 500. Nothing exercised it, which is why it
  # survived. This test is the guard that was missing.
  #
  # The assertion that matters is on a PLAYABLE song: with no fixture attachment
  # every url is nil, and asserting "key present" or "not an attachment object"
  # both pass on nil — the test would have passed even if the presenter were
  # broken to always return url: nil. So this attaches a real file first.
  test "albums action serializes playable songs and drops unplayable ones" do
    # SongPresenter calls audio_file.url, which needs a request host in tests.
    # Nothing in this suite had exercised that path with a real attachment before.
    # host! sets it on the request; assigning ActiveStorage::Current.url_options
    # here does not work because Current is reset per request.
    host! "example.com"

    playable = songs(:one)
    playable.audio_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "audio.mp3",
      content_type: "audio/mpeg"
    )

    get music_albums_zuke_index_url
    assert_response :success

    serialized = assigns(:album_songs)
    assert_not_nil serialized, "Should assign @album_songs"

    # songs(:one) belongs to first_album and is now playable.
    first_album_songs = serialized[albums(:first_album).id]
    assert_equal 1, first_album_songs.size,
      "only the playable song should be serialized"

    song = first_album_songs.first
    assert_not_nil song[:url], "a playable song must have a non-nil url"
    assert_kind_of String, song[:url], "url must be a string, not an attachment object"
    assert_match(/http|blob|rails/, song[:url], "url should look like a URL")

    # Every other fixture song has no audio_file, so nothing else should appear.
    serialized.each do |album_id, songs_for_album|
      next if album_id == albums(:first_album).id

      assert_empty songs_for_album,
        "album #{album_id} has no playable songs and should serialize none"
    end
  end

  # An artist with no songs raised NoMethodError on first_song.id while rendering
  # /zuke/artists. The fixture artist below has no songs on purpose.
  test "artists action renders an artist with no songs" do
    get music_artists_zuke_index_url
    assert_response :success
  end
end
