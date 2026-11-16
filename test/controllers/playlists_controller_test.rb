# frozen_string_literal: true

require "test_helper"

# The playlist surfaces render into Zuke's public "music-frame" turbo frame, so a
# signed-out visitor sees them — and they had no test coverage at all. That gap is
# how ZukePublicBoundaryTest's file list came to omit them: the guard was written
# from the files that came to mind, and these were not among them.
class PlaylistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @playlist = playlists(:one)
    @song = songs(:one)
  end

  test "index renders for a signed-out visitor" do
    with_soundcloud_stubbed do
      get playlists_url
      assert_response :success
    end
  end

  test "show renders for a signed-out visitor" do
    get playlist_url(@playlist)
    assert_response :success
  end

  # The other half of the boundary: what a playlist must NOT emit. A song with
  # only the master attached is unplayable, and its URL cannot reach the page.
  test "a song with only a full track never reaches the playlist response" do
    host! "example.com"
    @song.audio_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "full_track.mp3",
      content_type: "audio/mpeg"
    )

    get playlist_url(@playlist)
    assert_response :success

    assert_empty assigns(:songs), "an unplayable song must not be serialized into a playlist"
    assert_not_includes response.body, rails_blob_path(@song.audio_file.blob),
      "a full-track URL must never reach a public playlist response"
  end

  test "a playable song is serialized with its preview URL" do
    host! "example.com"
    @song.preview_audio.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "preview.mp3",
      content_type: "audio/mpeg"
    )

    get playlist_url(@playlist)
    assert_response :success

    assert_equal 1, assigns(:songs).size, "the playable song belongs in the playlist"
    assert_match(/preview\.mp3/, assigns(:songs).first[:url])
    assert_no_match(/full_track/, assigns(:songs).first[:url].to_s)
  end

  # The count on the card has to agree with what opening it shows. It used to
  # count every song in the playlist, playable or not.
  test "the index count matches what the playlist actually plays" do
    host! "example.com"
    @song.preview_audio.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "preview.mp3",
      content_type: "audio/mpeg"
    )

    with_soundcloud_stubbed do
      get playlists_url
      assert_response :success
    end

    assert_match(/1 song/, response.body,
      "the index should count the one playable song, not every song in the playlist")

    get playlist_url(@playlist)
    assert_equal 1, assigns(:songs).size,
      "the index card and the playlist itself must agree"
  end

  private

  # PlaylistsController#index reaches SoundCloud for the likes count. Stubbed
  # rather than left out: the subject of these tests is the rendered page, not
  # the network.
  def with_soundcloud_stubbed
    SoundcloudLikesService.stub(:fetch_likes, []) { yield }
  end
end
