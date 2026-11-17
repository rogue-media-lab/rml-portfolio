# frozen_string_literal: true

require "test_helper"

# The playlist surfaces render into Zuke's public "music-frame" turbo frame, so a
# signed-out visitor sees them — and they had no test coverage at all. That gap is
# how ZukePublicBoundaryTest's file list came to omit them: the guard was written
# from the files that came to mind, and these were not among them.
class PlaylistsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

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

  # The playlist door obeys the same rule as the player: the admin curates these songs, so
  # the master is theirs to hear. Without this, reverting the listener on
  # PlaylistsController#show leaves every other test green — the same gap the player's own
  # controller tests exist to close.
  test "a milk admin hears the full track in a playlist" do
    host! "example.com"
    @song.audio_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "full_track.mp3",
      content_type: "audio/mpeg"
    )
    @song.preview_audio.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "preview.mp3",
      content_type: "audio/mpeg"
    )

    sign_in milk_admins(:admin_one)
    get playlist_url(@playlist)
    assert_response :success

    assert_equal 1, assigns(:songs).size
    assert_match(/full_track\.mp3/, assigns(:songs).first[:url],
      "the admin curates these songs, so the playlist must serve the master")
    assert_no_match(/preview\.mp3/, assigns(:songs).first[:url])
  end

  # Same visibility rule as the player: an owned song is not public, so it cannot reach a
  # public playlist either.
  test "a guest does not see an owned song in a playlist" do
    host! "example.com"
    @song.preview_audio.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "preview.mp3",
      content_type: "audio/mpeg"
    )
    owner = User.create!(email: "playlist-scope-owner@example.com", password: "password123")
    @song.users << owner

    get playlist_url(@playlist)
    assert_response :success

    assert_empty assigns(:songs), "an owned song must not reach a public playlist"
  end

  # The card and the playlist have to agree for an owned song too. The card counted it while
  # opening the playlist hid it, because only one of the two asked the visibility scope.
  test "the index count agrees with the playlist for an owned song" do
    host! "example.com"
    @song.preview_audio.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "preview.mp3",
      content_type: "audio/mpeg"
    )
    owner = User.create!(email: "playlist-count-owner@example.com", password: "password123")
    @song.users << owner

    with_soundcloud_stubbed do
      get playlists_url
      assert_response :success
    end
    assert_equal 0, assigns(:playlist_counts)[@playlist.id],
      "the card must not count a song the playlist hides"

    get playlist_url(@playlist)
    assert_empty assigns(:songs), "and opening it must hide the song too"

    sign_in owner
    with_soundcloud_stubbed do
      get playlists_url
    end
    assert_equal 1, assigns(:playlist_counts)[@playlist.id],
      "the owner's card must count their own song"
  end

  private

  # PlaylistsController#index reaches SoundCloud for the likes count. Stubbed
  # rather than left out: the subject of these tests is the rendered page, not
  # the network.
  def with_soundcloud_stubbed
    SoundcloudLikesService.stub(:fetch_likes, []) { yield }
  end
end
