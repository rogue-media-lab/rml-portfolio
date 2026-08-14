require "test_helper"

class Api::V1::PlaylistsControllerTest < ActionDispatch::IntegrationTest
  TOKEN = "test_api_token_secret_hex_64_chars_long_enough_for_comparison_xxxx"

  setup do
    ENV["ZUKE_API_TOKEN"] = TOKEN
    @song1 = songs(:one)
    @song2 = songs(:two)
  end

  teardown do
    ENV.delete("ZUKE_API_TOKEN")
  end

  test "should reject request without auth" do
    post api_v1_playlists_url,
         params: { playlist: { name: "Test" } },
         as: :json
    assert_response :unauthorized
  end

  test "should create playlist with song IDs" do
    assert_difference("Playlist.count") do
      assert_difference("PlaylistSong.count", 2) do
        post api_v1_playlists_url,
             params: {
               playlist: {
                 name: "Work Mix",
                 description: "Curated by Hermes Agent",
                 song_ids: [ @song1.id, @song2.id ]
               }
             },
             headers: { "Authorization" => "Bearer #{TOKEN}" },
             as: :json
      end
    end

    assert_response :created

    body = JSON.parse(response.body)
    assert_equal "Work Mix", body["name"]
    assert_equal 2, body["song_count"]
    assert_includes body["url"], "/playlists/"
  end

  test "should preserve song order via position" do
    post api_v1_playlists_url,
         params: {
           playlist: {
             name: "Ordered Mix",
             song_ids: [ @song2.id, @song1.id ]
           }
         },
         headers: { "Authorization" => "Bearer #{TOKEN}" },
         as: :json

    assert_response :created

    playlist_id = JSON.parse(response.body)["id"]
    playlist_songs = PlaylistSong.where(playlist_id: playlist_id).order(:position)
    assert_equal @song2.id, playlist_songs.first.song_id
    assert_equal @song1.id, playlist_songs.second.song_id
  end

  test "should skip non-existent song IDs gracefully" do
    assert_difference("PlaylistSong.count", 1) do
      post api_v1_playlists_url,
           params: {
             playlist: {
               name: "Partial Mix",
               song_ids: [ @song1.id, 999999 ]
             }
           },
           headers: { "Authorization" => "Bearer #{TOKEN}" },
           as: :json
    end

    assert_response :created
    assert_equal 1, JSON.parse(response.body)["song_count"]
  end

  test "should return 422 when name is missing" do
    post api_v1_playlists_url,
         params: {
           playlist: {
             song_ids: [ @song1.id ]
           }
         },
         headers: { "Authorization" => "Bearer #{TOKEN}" },
         as: :json

    assert_response :unprocessable_entity
  end

  test "should create empty playlist when song_ids is empty" do
    assert_difference("Playlist.count") do
      post api_v1_playlists_url,
           params: {
             playlist: {
               name: "Empty Playlist",
               song_ids: []
             }
           },
           headers: { "Authorization" => "Bearer #{TOKEN}" },
           as: :json
    end

    assert_response :created
    assert_equal 0, JSON.parse(response.body)["song_count"]
  end
end
