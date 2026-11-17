# frozen_string_literal: true

require "test_helper"

class ZukeControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @milk_admin = milk_admins(:admin_one)
    @song_one = songs(:one)
    @song_two = songs(:two)
    @rock_genre = genres(:rock)
    @pop_genre = genres(:pop)
  end

  test "should get index" do
    get zuke_index_url
    assert_response :success
  end

  test "guest should see all public songs in music" do
    get music_list_zuke_index_url
    assert_response :success

    # Visibility: the scope the guest may see. This is what this test is about.
    scope = assigns(:songs_scope)
    assert_not_nil scope, "Should assign @songs_scope"
    assert_equal 27, scope.size, "Should load all 27 public songs"

    # Playability is separate: no fixture song has a preview attached, so nothing
    # renders. Asserting it here keeps the two concerns from being confused —
    # display filtering must not silently change visibility counts.
    assert_equal 0, assigns(:songs_for_display).size,
      "no fixture song has a preview, so none is playable"
  end

  test "milk admin should see all songs in music" do
    sign_in @milk_admin

    get music_list_zuke_index_url
    assert_response :success

    scope = assigns(:songs_scope)
    assert_not_nil scope
    assert_equal 27, scope.size, "Should load all 27 songs"
  end

  # The public player serves the preview, so a preview is what makes a song
  # playable. A song with the full track attached but no preview must NOT render
  # — that is the whole point of the boundary, and this is the test that says so.
  test "music hides songs that cannot be played" do
    host! "example.com"
    songs(:one).preview_audio.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "audio.mp3",
      content_type: "audio/mpeg"
    )

    get music_list_zuke_index_url
    assert_response :success

    assert_equal 27, assigns(:songs_scope).size, "visibility is unchanged"
    display = assigns(:songs_for_display)
    assert_equal 1, display.size, "only the playable song should be displayed"
    assert_not_nil display.first[:url], "the displayed song must have a URL"
  end

  # The other half of that rule, and the one that actually protects the master:
  # a full track alone gets a song onto NO public surface, and its URL never
  # reaches the JSON the player loads.
  test "a song with only the full track is not playable and its URL never ships" do
    host! "example.com"
    song = songs(:one)
    song.audio_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "full_track.mp3",
      content_type: "audio/mpeg"
    )

    assert_not song.playable?, "a full track with no preview is not playable"
    assert_empty Song.playable.where(id: song.id), "the playable scope must agree"

    # A path helper, not `.url`: `.url` needs ActiveStorage::Current, which a
    # request has and this line does not.
    full_track_path = rails_blob_path(song.audio_file.blob)

    get music_list_zuke_index_url
    assert_response :success

    assert_empty assigns(:songs_for_display), "nothing with only a full track may display"
    assert_not_includes response.body, full_track_path,
      "the full-track URL must never reach a public response"
  end

  # The genres action ranks the top 20 songs per genre in SQL. Two things have to
  # hold at once: the ranking must only consider playable songs (so the window
  # does not fill with songs that will be dropped), and the limit must still
  # apply. No fixture song has a preview, so this attaches one to every song to
  # actually exercise the limit.
  test "genres action returns only playable songs and still limits to 20" do
    host! "example.com"

    # NB: with no argument the fixture accessor returns an Array of records, not
    # the old name => record Hash. Destructuring |_name, song| yields nil here.
    songs.each do |song|
      song.preview_audio.attach(
        io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
        filename: "audio.mp3",
        content_type: "audio/mpeg"
      )
    end

    get music_genres_zuke_index_url
    assert_response :success

    grouped_genres = assigns(:grouped_genres)
    assert_not_nil grouped_genres
    assert_equal 2, grouped_genres.size, "Rock and Pop"

    # Rock has 25 fixture songs plus song 'one' = 26 playable, so the limit bites.
    assert_equal 20, grouped_genres[@rock_genre].size,
      "the 20-song window must still apply, and apply to playable songs"
    assert_equal 1, grouped_genres[@pop_genre].size

    # Every song that reached the view must be playable.
    assigns(:genre_songs).each_value do |serialized|
      serialized.each do |song|
        assert_not_nil song[:url], "an unplayable song reached the view"
      end
    end
  end

  # A genre whose songs are all unplayable renders no cards, and its heading
  # count must agree — that disagreement is what the pre-filter ranking caused.
  test "genres action shows nothing when no song is playable" do
    get music_genres_zuke_index_url
    assert_response :success

    assigns(:grouped_genres).each_value do |songs|
      assert_empty songs, "unplayable songs must not be ranked into the window"
    end
  end

  # GET /zuke/albums rendered "zuke/turbo_frames/albums", a partial that did not
  # exist, so the route returned a 500. Nothing exercised it, which is why it
  # survived. This test is the guard that was missing.
  #
  # The assertion that matters is on a PLAYABLE song: with no fixture attachment
  # every url is nil, and asserting "key present" or "not an attachment object"
  # both pass on nil — the test would have passed even if the presenter were
  # broken to always return url: nil. So this attaches a real file first.
  test "albums action serializes playable songs and drops unplayable ones" do
    # SongPresenter calls audio_file.url, which needs a request host in tests.
    # Nothing in this suite had exercised that path with a real attachment before.
    # host! sets it on the request; assigning ActiveStorage::Current.url_options
    # here does not work because Current is reset per request.
    host! "example.com"

    playable = songs(:one)
    playable.preview_audio.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "audio.mp3",
      content_type: "audio/mpeg"
    )

    get music_albums_zuke_index_url
    assert_response :success

    serialized = assigns(:album_songs)
    assert_not_nil serialized, "Should assign @album_songs"

    # songs(:one) belongs to first_album and is now playable.
    first_album_songs = serialized[albums(:first_album).id]
    assert_equal 1, first_album_songs.size,
      "only the playable song should be serialized"

    song = first_album_songs.first
    assert_not_nil song[:url], "a playable song must have a non-nil url"
    assert_kind_of String, song[:url], "url must be a string, not an attachment object"
    assert_match(/http|blob|rails/, song[:url], "url should look like a URL")

    # Every other fixture song has no audio_file, so nothing else should appear.
    serialized.each do |album_id, songs_for_album|
      next if album_id == albums(:first_album).id

      assert_empty songs_for_album,
        "album #{album_id} has no playable songs and should serialize none"
    end
  end

  # An artist with no songs raised NoMethodError on first_song.id while rendering
  # /zuke/artists. The fixture artist below has no songs on purpose.
  test "artists action renders an artist with no songs" do
    get music_artists_zuke_index_url
    assert_response :success
  end

  # --- who hears full tracks -----------------------------------------------------
  #
  # The wire-up from controller to presenter is the part that can silently be nil, and a
  # listener that never arrives looks exactly like an unentitled one. These go through the
  # action rather than calling the presenter directly, so a reverted `listener:` is caught.

  test "a milk admin hears full tracks on the player" do
    host! "example.com"
    attach_playable_audio(songs(:one))

    sign_in @milk_admin
    get music_list_zuke_index_url
    assert_response :success

    assert_match(/full_track\.mp3/, assigns(:songs_for_display).first[:url],
      "the admin curates these songs, so the player must serve the master")
  end

  test "a guest still hears only previews on the player" do
    host! "example.com"
    attach_playable_audio(songs(:one))

    get music_list_zuke_index_url
    assert_response :success

    url = assigns(:songs_for_display).first[:url]
    assert_match(/preview\.mp3/, url)
    assert_no_match(/full_track\.mp3/, url,
      "the master must never reach a signed-out visitor")
  end

  # Creating an account is not itself a licence to the full track. Only ownership or
  # `can_download` is — the same rule the download endpoints ask.
  test "a signed-in user with no right still hears only previews" do
    host! "example.com"
    attach_playable_audio(songs(:one))

    stranger = User.create!(email: "player-stranger@example.com", password: "password123")
    sign_in stranger
    get music_list_zuke_index_url
    assert_response :success

    url = assigns(:songs_for_display).first[:url]
    assert_match(/preview\.mp3/, url)
    assert_no_match(/full_track\.mp3/, url)
  end

  # --- who sees whose songs ------------------------------------------------------
  #
  # Visibility and entitlement are separate concerns, and both have to hold: a song a user
  # cannot see is a song they cannot hear. The scope used to exclude every song tied to an
  # account, which hid a user's own upload from that user.

  test "a signed-in user sees the songs that are theirs" do
    host! "example.com"
    owner = User.create!(email: "scope-owner@example.com", password: "password123")
    songs(:one).users << owner

    sign_in owner
    get music_list_zuke_index_url
    assert_response :success

    scope = assigns(:songs_scope)
    assert_includes scope, songs(:one),
      "a user's own upload must be visible to them"
    assert_equal 27, scope.size,
      "their own song plus the 26 songs that belong to no account"
  end

  # Ownership still hides a song from everyone else — that half already worked, and this
  # keeps the fix above from having quietly loosened it.
  test "a guest does not see songs that belong to an account" do
    host! "example.com"
    owner = User.create!(email: "scope-guest-owner@example.com", password: "password123")
    songs(:one).users << owner

    get music_list_zuke_index_url
    assert_response :success

    scope = assigns(:songs_scope)
    assert_not_includes scope, songs(:one)
    assert_equal 26, scope.size
  end

  # Visibility is one rule, and every surface has to ask it: a song belonging to an account
  # is not public, so it must not reach artists, albums or genres either. The scope used to
  # be applied only to the main player, which let one surface hide a song that three others
  # showed.
  test "a guest does not see an owned song on artists, albums or genres" do
    host! "example.com"
    owner = User.create!(email: "surface-owner@example.com", password: "password123")
    song = songs(:one)
    attach_playable_audio(song)
    song.genres << genres(:rock)
    song.users << owner

    get music_artists_zuke_index_url
    assert_response :success
    assert_empty assigns(:artist_songs)[song.artist_id],
      "an owned song must not reach an artist card"

    get music_albums_zuke_index_url
    assert_response :success
    assert_empty assigns(:album_songs)[song.album_id],
      "an owned song must not reach an album card"

    get music_genres_zuke_index_url
    assert_response :success
    assert_not_includes assigns(:grouped_genres).values.flatten, song,
      "an owned song must not reach a genre card"
  end

  # The other half of the same rule, on a surface that was not asking it before: the owner
  # still sees their own song where the guest does not.
  test "their own song still reaches the artist card for the user who owns it" do
    host! "example.com"
    owner = User.create!(email: "surface-owner-2@example.com", password: "password123")
    song = songs(:one)
    attach_playable_audio(song)
    song.users << owner

    sign_in owner
    get music_artists_zuke_index_url
    assert_response :success

    assert_equal 1, assigns(:artist_songs)[song.artist_id].size,
      "a user's own song must reach their artist card"
  end

  # Signing in from the player used to be a one-way trip: the menu still offered "Admin Sign
  # In" while signed in, and nothing anywhere linked back to the player — which strands you on
  # a device with no address bar. These two links are the only way across.
  test "the player offers a way back to the admin once signed in, and sign-in otherwise" do
    host! "example.com"

    get music_list_zuke_index_url
    assert_response :success
    assert_match(/Admin Sign In/, response.body)
    assert_no_match(/Admin Dashboard/, response.body,
      "a visitor who is not signed in must not be offered the dashboard")

    sign_in @milk_admin
    get music_list_zuke_index_url
    assert_response :success
    assert_match(/Admin Dashboard/, response.body,
      "signed in, the menu must lead back to the admin")
    assert_no_match(/Admin Sign In/, response.body)
  end

  private

  # Attaches a master and a preview with distinct filenames, so whichever one the
  # presenter chose is readable off the serialized hash.
  def attach_playable_audio(song)
    song.audio_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "full_track.mp3",
      content_type: "audio/mpeg"
    )
    song.preview_audio.attach(
      io: File.open(Rails.root.join("test/fixtures/files/audio.mp3")),
      filename: "preview.mp3",
      content_type: "audio/mpeg"
    )
    song
  end
end
