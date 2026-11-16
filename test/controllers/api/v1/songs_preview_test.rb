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
  include ActiveJob::TestHelper

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

  # Omitting the preview no longer leaves a song permanently unplayable: the model
  # now schedules a server-side cut. The assertion that used to sit here — "a
  # caller that sends no preview must not get one invented for it" — described the
  # behaviour before that wire existed, and passed only because the test adapter
  # buffers enqueued jobs instead of running them.
  test "preview is optional — the song saves and the server schedules the cut" do
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

    # Nothing is cut during the request...
    assert_not song.preview_audio.attached?,
               "the cut belongs out of band, not in the request"

    # ...but it is scheduled, so the song is not left publicly invisible. This is
    # the assertion that would have caught the job being wired to nothing.
    assert_enqueued_with(job: GeneratePreviewJob)
  end

  test "an unauthenticated request cannot attach a preview" do
    assert_no_difference("Song.count") do
      post api_v1_songs_url, params: preview_params
    end
    assert_response :unauthorized
  end
end
