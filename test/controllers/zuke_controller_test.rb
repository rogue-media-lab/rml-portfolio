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

    # Visibility: the scope the guest may see. This is what this test is about.
    scope = assigns(:songs_scope)
    assert_not_nil scope, "Should assign @songs_scope"
    assert_equal 27, scope.size, "Should load all 27 public songs"

    # Playability is separate: no fixture song has an attached audio_file, so
    # nothing renders. Asserting it here keeps the two concerns from being
    # confused — display filtering must not silently change visibility counts.
    assert_equal 0, assigns(:songs_for_display).size,
      "no fixture song has an audio_file, so none is playable"
  end

  test "milk admin should see all songs in music" do
    sign_in @milk_admin

    get music_list_zuke_index_url
    assert_response :success

    scope = assigns(:songs_scope)
    assert_not_nil scope
    assert_equal 27, scope.size, "Should load all 27 songs"
  end

  test "music hides songs that cannot be played" do
    host! "example.com"
    songs(:one).audio_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "audio.mp3",
      content_type: "audio/mpeg"
    )

    get music_list_zuke_index_url
    assert_response :success

    assert_equal 27, assigns(:songs_scope).size, "visibility is unchanged"
    display = assigns(:songs_for_display)
    assert_equal 1, display.size, "only the playable song should be displayed"
    assert_not_nil display.first[:url], "the displayed song must have a URL"
  end

  # The genres action ranks the top 20 songs per genre in SQL. Two things have to
  # hold at once: the ranking must only consider playable songs (so the window
  # does not fill with songs that will be dropped), and the limit must still
  # apply. No fixture song has an audio_file, so this attaches one to enough
  # songs to actually exercise the limit.
  test "genres action returns only playable songs and still limits to 20" do
    host! "example.com"

    # NB: with no argument the fixture accessor returns an Array of records, not
    # the old name => record Hash. Destructuring |_name, song| yields nil here.
    songs.each do |song|
      song.audio_file.attach(
        io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
        filename: "audio.mp3",
        content_type: "audio/mpeg"
      )
    end

    get music_genres_zuke_index_url
    assert_response :success

    grouped_genres = assigns(:grouped_genres)
    assert_not_nil grouped_genres
    assert_equal 2, grouped_genres.size, "Rock and Pop"

    # Rock has 25 fixture songs plus song 'one' = 26 playable, so the limit bites.
    assert_equal 20, grouped_genres[@rock_genre].size,
      "the 20-song window must still apply, and apply to playable songs"
    assert_equal 1, grouped_genres[@pop_genre].size

    # Every song that reached the view must be playable.
    assigns(:genre_songs).each_value do |serialized|
      serialized.each do |song|
        assert_not_nil song[:url], "an unplayable song reached the view"
      end
    end
  end

  # A genre whose songs are all unplayable renders no cards, and its heading
  # count must agree — that disagreement is what the pre-filter ranking caused.
  test "genres action shows nothing when no song is playable" do
    get music_genres_zuke_index_url
    assert_response :success

    assigns(:grouped_genres).each_value do |songs|
      assert_empty songs, "unplayable songs must not be ranked into the window"
    end
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
