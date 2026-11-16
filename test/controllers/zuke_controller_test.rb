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
  test "albums action renders and serializes each album's songs" do
    get music_albums_zuke_index_url
    assert_response :success

    grouped = assigns(:albums)
    assert_not_nil grouped, "Should assign @albums"

    serialized = assigns(:album_songs)
    assert_not_nil serialized, "Should assign @album_songs"

    # Every song hash must carry the presenter's keys, not a raw attachment.
    serialized.each_value do |songs|
      songs.each do |song|
        assert song.key?(:url), "serialized song is missing :url"
        assert song.key?(:title), "serialized song is missing :title"
        assert_not_kind_of ActiveStorage::Attached::One, song[:url],
          "view received an attachment object instead of a URL"
      end
    end
  end

  # An artist with no songs raised NoMethodError on first_song.id while rendering
  # /zuke/artists. The fixture artist below has no songs on purpose.
  test "artists action renders an artist with no songs" do
    get music_artists_zuke_index_url
    assert_response :success
  end
end
