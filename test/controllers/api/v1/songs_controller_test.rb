require "test_helper"

class Api::V1::SongsControllerTest < ActionDispatch::IntegrationTest
  # Tests for the agent-facing song upload endpoint.
  # Auth is via Bearer token — stored in Rails credentials (:api_token)
  # or ENV["ZUKE_API_TOKEN"]. Tests set the ENV var.

  TOKEN = "test_api_token_secret_hex_64_chars_long_enough_for_comparison_xxxx"

  setup do
    ENV["ZUKE_API_TOKEN"] = TOKEN
  end

  teardown do
    ENV.delete("ZUKE_API_TOKEN")
  end

  test "should reject request without Authorization header" do
    post api_v1_songs_url, params: { song: { title: "Test" } }
    assert_response :unauthorized
    assert_equal "Unauthorized", JSON.parse(response.body)["error"]
  end

  test "should reject request with wrong token" do
    post api_v1_songs_url,
         params: { song: { title: "Test" } },
         headers: { "Authorization" => "Bearer wrong_token" }
    assert_response :unauthorized
  end

  test "should create song with audio file upload" do
    audio_file = fixture_file_upload("test_audio.mp3", "audio/mpeg")

    assert_difference("Song.count") do
      assert_difference("Artist.count") do
        post api_v1_songs_url,
             params: {
               song: {
                 title: "Tom Sawyer",
                 artist_name: "Rush",
                 audio_file: audio_file
               }
             },
             headers: auth_headers
      end
    end

    assert_response :created

    body = JSON.parse(response.body)
    assert_equal "Tom Sawyer", body["title"]
    assert_equal "Rush", body["artist"]
    assert_not_nil body["id"]
    assert_includes body["url"], "/zuke/music"

    song = Song.find(body["id"])
    assert song.audio_file.attached?
    assert_equal "Rush", song.artist.name
  end

  test "should create song with image and metadata" do
    audio_file = fixture_file_upload("test_audio.mp3", "audio/mpeg")
    image_file = fixture_file_upload("cover.jpg", "image/jpeg")

    assert_difference("Song.count") do
      post api_v1_songs_url,
           params: {
             song: {
               title: "Learning to Fly",
               artist_name: "Pink Floyd",
               album_title: "A Momentary Lapse of Reason",
               audio_file: audio_file,
               image: image_file,
               image_credit: "Photographer Name",
               audio_source: "YouTube"
             }
           },
           headers: auth_headers
    end

    assert_response :created

    song = Song.find(JSON.parse(response.body)["id"])
    assert song.audio_file.attached?
    assert song.image.attached?
    assert_equal "A Momentary Lapse of Reason", song.album.title
    assert_equal "Photographer Name", song.image_credit
    assert_equal "YouTube", song.audio_source
  end

  test "should reuse existing artist" do
    existing = Artist.create!(name: "Rush")
    audio_file = fixture_file_upload("test_audio.mp3", "audio/mpeg")

    assert_no_difference("Artist.count") do
      post api_v1_songs_url,
           params: {
             song: {
               title: "Limelight",
               artist_name: "Rush",
               audio_file: audio_file
             }
           },
           headers: auth_headers
    end

    assert_response :created
    assert_equal existing.id, Song.find(JSON.parse(response.body)["id"]).artist_id
  end

  test "should return 422 when title is missing" do
    post api_v1_songs_url,
         params: { song: { artist_name: "Rush" } },
         headers: auth_headers

    assert_response :unprocessable_entity
    assert_not_nil JSON.parse(response.body)["errors"]
  end

  test "should return 422 when artist_name is missing" do
    post api_v1_songs_url,
         params: { song: { title: "Test Song" } },
         headers: auth_headers

    assert_response :unprocessable_entity
  end

  test "should accept token via query param fallback" do
    audio_file = fixture_file_upload("test_audio.mp3", "audio/mpeg")

    assert_difference("Song.count") do
      post api_v1_songs_url,
           params: {
             token: TOKEN,
             song: {
               title: "Query Param Auth",
               artist_name: "Test Artist",
               audio_file: audio_file
             }
           }
    end

    assert_response :created
  end

  # Uploading into an account is what makes the per-user library reachable: before this every
  # API upload was ownerless, and therefore public.
  test "an owner_email puts the upload in that account, and out of the public library" do
    owner = User.create!(email: "uploader@example.com", password: "password123")
    audio_file = fixture_file_upload("test_audio.mp3", "audio/mpeg")

    post api_v1_songs_url,
         params: {
           song: {
             title: "Mine",
             artist_name: "Test Artist",
             audio_file: audio_file,
             owner_email: owner.email
           }
         },
         headers: auth_headers

    assert_response :created
    assert_equal [ owner.email ], JSON.parse(response.body)["owners"]

    song = Song.find(JSON.parse(response.body)["id"])
    assert_equal [ owner.id ], song.users.map(&:id)

    # The consequence, asserted rather than assumed: an owned song is not public.
    assert_not_includes Song.visible_to(nil), song,
      "an owned upload must not be in the library a signed-out visitor sees"
    assert_includes Song.visible_to(owner), song,
      "it belongs to the account it was uploaded for"
  end

  # A mistyped address must not quietly publish the song to everyone. Refusing is the point:
  # the caller asked for a private upload and would otherwise get a public one, with a 201
  # saying it worked.
  test "an owner_email with no account is refused, and nothing is created" do
    audio_file = fixture_file_upload("test_audio.mp3", "audio/mpeg")

    assert_no_difference("Song.count") do
      post api_v1_songs_url,
           params: {
             song: {
               title: "Orphan",
               artist_name: "Test Artist",
               audio_file: audio_file,
               owner_email: "nobody@example.com"
             }
           },
           headers: auth_headers
    end

    assert_response :unprocessable_entity
    assert_equal [ "no account with that email" ],
      JSON.parse(response.body)["errors"]["owner_email"]
  end

  # No owner still means the library, exactly as before the field existed.
  test "an upload with no owner_email stays in the public library" do
    audio_file = fixture_file_upload("test_audio.mp3", "audio/mpeg")

    post api_v1_songs_url,
         params: { song: { title: "Public", artist_name: "Test Artist", audio_file: audio_file } },
         headers: auth_headers

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal [], body["owners"]
    assert_includes Song.visible_to(nil), Song.find(body["id"])
  end

  private

  def auth_headers
    { "Authorization" => "Bearer #{TOKEN}" }
  end
end
