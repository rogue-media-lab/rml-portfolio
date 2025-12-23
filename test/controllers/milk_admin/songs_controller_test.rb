require "test_helper"

class MilkAdmin::SongsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = milk_admins(:admin_one)
    @song = songs(:one)
    # Ensure attachments are clean or exist
    @song.image.attach(io: File.open(Rails.root.join("test/fixtures/files/cover.jpg")), filename: "cover.jpg", content_type: "image/jpeg") unless @song.image.attached?
  end

  test "should redirect index when not logged in" do
    get milk_admin_songs_url
    assert_redirected_to new_milk_admin_session_url
  end

  test "should get index when logged in" do
    sign_in @admin
    get milk_admin_songs_url
    assert_response :success
  end

  test "should get dashboard" do
    sign_in @admin
    get milk_admin_songs_dashboard_url
    assert_response :success
  end

  test "should get new" do
    sign_in @admin
    get new_milk_admin_song_url
    assert_response :success
  end

  test "should create song" do
    sign_in @admin
    assert_difference("Song.count") do
      post milk_admin_songs_url, params: { 
        song: { 
          title: "New Song",
          artist_attributes: { name: "New Artist" },
          album_attributes: { title: "New Album" }
        } 
      }
    end

    assert_redirected_to milk_admin_songs_url
  end

  test "should get edit" do
    sign_in @admin
    get edit_milk_admin_song_url(@song)
    assert_response :success
  end

  test "should update song" do
    sign_in @admin
    patch milk_admin_song_url(@song), params: { song: { title: "Updated Title" } }
    assert_redirected_to milk_admin_songs_url
    @song.reload
    assert_equal "Updated Title", @song.title
  end

  test "should destroy song" do
    sign_in @admin
    assert_difference("Song.count", -1) do
      delete milk_admin_song_url(@song)
    end

    assert_redirected_to milk_admin_songs_url
  end
end
