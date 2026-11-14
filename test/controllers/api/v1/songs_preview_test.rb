# frozen_string_literal: true

require "test_helper"

# The 30-second preview on the agent-facing upload endpoint.
#
# Why these exist: adding an attachment without adding it to the strong-params permit
# list is a silent no-op. The request still returns 201, the song still saves, and the
# preview is simply never attached — which looks like success from every angle. The
# third test below is the one that catches that, by asserting the param survives
# filtering rather than only that the request succeeded.
class Api::V1::SongsPreviewTest < ActionDispatch::IntegrationTest
  TOKEN = "test_api_token_secret_hex_64_chars_long_enough_for_comparison_xxxx"

  setup do
    ENV["ZUKE_API_TOKEN"] = TOKEN
  end

  teardown do
    ENV.delete("ZUKE_API_TOKEN")
  end

  def auth_headers
    { "Authorization" => "Bearer #{TOKEN}" }
  end

  def preview_params(extra = {})
    {
      song: {
        title: "Tom Sawyer",
        artist_name: "Rush",
        audio_file: fixture_file_upload("test_audio.mp3", "audio/mpeg"),
        preview_audio: fixture_file_upload("test_audio.mp3", "audio/mpeg")
      }.merge(extra)
    }
  end

  test "attaches the preview when preview_audio is provided" do
    post api_v1_songs_url, params: preview_params, headers: auth_headers

    assert_response :created
    song = Song.find(JSON.parse(response.body)["id"])
    assert song.audio_file.attached?, "full track should be attached"
    assert song.preview_audio.attached?, "preview should be attached"
  end

  test "preview is optional — a song without one still saves" do
    post api_v1_songs_url,
         params: {
           song: {
             title: "Tom Sawyer",
             artist_name: "Rush",
             audio_file: fixture_file_upload("test_audio.mp3", "audio/mpeg")
           }
         },
         headers: auth_headers

    assert_response :created
    song = Song.find(JSON.parse(response.body)["id"])
    assert song.audio_file.attached?
    assert_not song.preview_audio.attached?,
               "a caller that sends no preview must not get one invented for it"
  end

  test "preview_audio is permitted, not silently dropped by strong params" do
    # This is the regression that matters. If :preview_audio is ever removed from the
    # permit list, the request still returns 201 and the attach block silently no-ops.
    post api_v1_songs_url, params: preview_params, headers: auth_headers

    assert_response :created
    song = Song.find(JSON.parse(response.body)["id"])

    assert song.preview_audio.attached?,
           "preview_audio was accepted by the controller but not attached — " \
           "check that :preview_audio is in the strong-params permit list"
  end

  test "an unauthenticated request cannot attach a preview" do
    assert_no_difference("Song.count") do
      post api_v1_songs_url, params: preview_params
    end
    assert_response :unauthorized
  end
end
