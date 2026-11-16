require "test_helper"

# Downloading a song's own files, as a signed-in user.
#
# Playing is public; taking a copy is not. These tests pin the rule from the
# permission side rather than the endpoint side, because the endpoint is only a
# caller of Song#downloadable_by?.
class ZukeDownloadsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user  = User.create!(email: "dl@example.com",    password: "password123")
    @other = User.create!(email: "other@example.com", password: "password123")

    @song = Song.create!(title: "Mine", artist: Artist.create!(name: "Mason Roberts"))
    attach(@song, :audio_file,   "audio.mp3", "audio/mpeg")   # master
    attach(@song, :preview_audio, "tone.flac", "audio/flac")  # deliberately a different type,
    @song.reload                                              # so "which file came back" is provable
  end

  test "signed out, you get no file at all" do
    get zuke_song_download_url(@song)
    assert_response :redirect
    assert_not_equal "attachment", response.headers["Content-Disposition"].to_s.downcase
  end

  test "signing up is not a download right" do
    sign_in @user
    get zuke_song_download_url(@song)
    assert_response :forbidden
  end

  test "an account granted can_download may take the master" do
    @user.update!(can_download: true)
    sign_in @user

    get zuke_song_download_url(@song)

    assert_response :success
    assert_equal "audio/mpeg", response.media_type
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_equal File.binread(Rails.root.join("test/fixtures/files/audio.mp3")), response.body
  end

  test "your own upload is yours to download" do
    @song.users << @user
    sign_in @user

    get zuke_song_download_url(@song)

    assert_response :success
    assert_equal "audio/mpeg", response.media_type
  end

  test "someone else's upload is not" do
    @song.users << @other
    sign_in @user

    get zuke_song_download_url(@song)

    assert_response :forbidden
  end

  # The default is the master, so the thing worth proving is that asking for
  # something else actually gets something else.
  test "?file=preview returns the preview, not the master" do
    @user.update!(can_download: true)
    sign_in @user

    get zuke_song_download_url(@song, file: "preview")

    assert_response :success
    assert_equal "audio/flac", response.media_type
  end

  # An unknown name must not fall back to the master — otherwise a typo in a
  # ?file= parameter hands out the full track.
  test "an unrecognised ?file= is a 404, never the master" do
    @user.update!(can_download: true)
    sign_in @user

    get zuke_song_download_url(@song, file: "master_or_whatever")

    assert_response :not_found
  end

  test "404 for a song that is not there" do
    @user.update!(can_download: true)
    sign_in @user

    get zuke_song_download_url(id: 999_999)

    assert_response :not_found
  end

  test "404 when the requested file was never attached" do
    @user.update!(can_download: true)
    sign_in @user

    get zuke_song_download_url(@song, file: "banner_video")

    assert_response :not_found
  end

  private

  def attach(song, name, fixture, content_type)
    song.public_send(name).attach(
      io: StringIO.new(File.binread(Rails.root.join("test/fixtures/files", fixture))),
      filename: fixture,
      content_type: content_type
    )
  end
end
