require "test_helper"

# The agent's door to a song's files — the twin of the signed-in user's download.
# It exists because recovering a song's own audio without it meant reading a page
# snapshot taken before a deploy: the only remaining route to a master's URL once
# a song has left the public player.
class Api::V1::SongsDownloadTest < ActionDispatch::IntegrationTest
  TOKEN = "test_api_token_secret_hex_64_chars_long_enough_for_comparison_xxxx"

  setup do
    ENV["ZUKE_API_TOKEN"] = TOKEN
    @song = Song.create!(title: "Recoverable", artist: Artist.create!(name: "Mason Roberts"))
    attach(@song, :audio_file, "audio.mp3", "audio/mpeg")   # master
    attach(@song, :preview_audio, "tone.flac", "audio/flac") # deliberately a different type,
    @song.reload                                             # so "which file came back" is provable
  end

  teardown do
    ENV.delete("ZUKE_API_TOKEN")
  end

  test "requires the token" do
    get download_api_v1_song_url(@song)
    assert_response :unauthorized
  end

  test "serves the master to a token holder" do
    get download_api_v1_song_url(@song), headers: auth_headers

    assert_response :success
    assert_equal "audio/mpeg", response.media_type
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_equal File.binread(Rails.root.join("test/fixtures/files/audio.mp3")), response.body
  end

  test "?file=preview returns the preview instead" do
    get download_api_v1_song_url(@song, file: "preview"), headers: auth_headers

    assert_response :success
    assert_equal "audio/flac", response.media_type
  end

  test "an unrecognised ?file= is a 404, never the master" do
    get download_api_v1_song_url(@song, file: "nonsense"), headers: auth_headers

    assert_response :not_found
    assert_equal "No such file", JSON.parse(response.body)["error"]
  end

  test "404 for a song that is not there" do
    get download_api_v1_song_url(id: 999_999), headers: auth_headers

    assert_response :not_found
    assert_equal "Not found", JSON.parse(response.body)["error"]
  end

  private

  def auth_headers
    { "Authorization" => "Bearer #{TOKEN}" }
  end

  def attach(song, name, fixture, content_type)
    song.public_send(name).attach(
      io: StringIO.new(File.binread(Rails.root.join("test/fixtures/files", fixture))),
      filename: fixture,
      content_type: content_type
    )
  end
end
