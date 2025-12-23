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
end
