# frozen_string_literal: true

require "test_helper"

# The 30-second preview on the agent-facing upload endpoint.
#
# Two things these tests exist to catch, both of which look like success from outside:
#
#   1. An attachment that isn't in the strong-params permit list. The request still
#      returns 201 and the song still saves; the preview is simply never attached.
#   2. The two attachments being crossed — audio_file landing on preview_audio. That is
#      why the two uploads use DIFFERENT fixture files and assert on the resulting
#      filenames. With one shared fixture, a crossed wire passes silently.
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

  # Deliberately different files for the two attachments — see the class comment.
  def preview_params
    {
      song: {
        title: "Tom Sawyer",
        artist_name: "Rush",
        audio_file: fixture_file_upload("audio.mp3", "audio/mpeg"),
        preview_audio: fixture_file_upload("test_audio.mp3", "audio/mpeg")
      }
    }
  end

  test "attaches the preview, and keeps the two attachments distinct" do
    post api_v1_songs_url, params: preview_params, headers: auth_headers

    assert_response :created
    song = Song.find(JSON.parse(response.body)["id"])

    assert song.audio_file.attached?, "full track should be attached"
    assert song.preview_audio.attached?,
           "preview_audio was accepted but not attached — check that :preview_audio is " \
           "in the strong-params permit list in Api::V1::SongsController"

    # The assertion that matters: each attachment holds the file it was sent.
    assert_equal "audio.mp3", song.audio_file.filename.to_s
    assert_equal "test_audio.mp3", song.preview_audio.filename.to_s,
                 "preview_audio holds the wrong file — the two attachments are crossed"
  end

  test "preview is optional — a song without one still saves" do
    post api_v1_songs_url,
         params: {
           song: {
             title: "Tom Sawyer",
             artist_name: "Rush",
             audio_file: fixture_file_upload("audio.mp3", "audio/mpeg")
           }
         },
         headers: auth_headers

    assert_response :created
    song = Song.find(JSON.parse(response.body)["id"])
    assert song.audio_file.attached?
    assert_not song.preview_audio.attached?,
               "a caller that sends no preview must not get one invented for it"
  end

  test "an unauthenticated request cannot attach a preview" do
    assert_no_difference("Song.count") do
      post api_v1_songs_url, params: preview_params
    end
    assert_response :unauthorized
  end
end
