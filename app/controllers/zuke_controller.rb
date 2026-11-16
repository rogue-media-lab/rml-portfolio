# frozen_string_literal: true

# The ZukeController handles all requests related to the Zuke music player.
# It is responsible for serving the main player interface, as well as handling
# requests for artists, albums, genres, and search functionality.
class ZukeController < ApplicationController
  include ZukeAuth

  def index; end

  # Serves the main music player interface, loading all applicable songs.
  #
  # @songs_scope is the visible library (who sees whose songs). @songs_for_display
  # is what actually renders — visibility plus playability, since a song with no
  # preview cannot be played on a public surface. Keeping them separate means the
  # visibility tests measure visibility and not playability.
  def music
    local_songs = load_songs
    @songs_scope = local_songs
    @songs_for_display, @songs_data = serialize_songs_for_player(local_songs)
  end

  # Renders the list of all artists, grouped by the first letter of their name.
  #
  # Each artist's songs are serialized through the presenter (see #albums) so the
  # view renders the shared smart-image component. Previously the partial reached
  # for first_song.audio_file, which renders an attachment object, not a URL.
  def artists
    # Eager-load each artist's songs, their artist, the attachments (blobs
    # included) that SongPresenter reads, and the artwork the view falls back to,
    # so serializing and rendering fire no per-artist or per-song query.
    @artists = Artist.includes(
      { image_attachment: :blob },
      { albums: { cover_art_attachment: :blob } },
      songs: song_serialization_includes
    ).order(:name)
    @grouped_artists = @artists.group_by { |a| a.name.first.upcase }

    @artist_songs = @artists.each_with_object({}) do |artist, memo|
      memo[artist.id] = serialize_songs_for_player(artist.songs).first
    end

    render partial: "zuke/turbo_frames/artists", formats: [ :html ]
  end

  # Renders the list of all albums, grouped by the first letter of their title.
  #
  # Each album's songs are serialized through the presenter (same shape the main
  # player uses) so the view can render the shared smart-image component instead
  # of reaching for a raw attachment. Before this, the partial named here did not
  # exist and the route returned a 500.
  def albums
    all_albums = Album.includes(
      :artist,
      { cover_art_attachment: :blob },
      songs: song_serialization_includes
    ).order(:title)

    @album_songs = all_albums.each_with_object({}) do |album, memo|
      memo[album.id] = serialize_songs_for_player(album.songs).first
    end

    @albums = all_albums.group_by { |a| a.title.first.upcase }

    render partial: "zuke/turbo_frames/albums", formats: [ :html ]
  end

  # Renders a list of genres, each with a sample of associated songs.
  def genres
    # Top 20 songs per genre, ranked in SQL to avoid an N+1.
    #
    # The playable join is in the query, not applied afterwards: taking 20 rows
    # and then dropping the unplayable ones loses playable songs that fell
    # outside the window, and makes the heading's track count disagree with the
    # cards actually rendered.
    sql = <<-SQL
      SELECT id FROM (
        SELECT
          s.id,
          sg.genre_id,
          ROW_NUMBER() OVER(PARTITION BY sg.genre_id ORDER BY s.created_at DESC) as rn
        FROM songs s
        INNER JOIN song_genres sg ON s.id = sg.song_id
        INNER JOIN active_storage_attachments asa
          ON asa.record_type = 'Song'
         AND asa.record_id = s.id
         AND asa.name = 'preview_audio'
      ) ranked_songs
      WHERE rn <= 20
    SQL

    song_ids = ActiveRecord::Base.connection.execute(sql).pluck("id")

    # Eager load the songs, their associations, and the attachments SongPresenter
    # reads — without the attachments this comment's "no N+1" claim was false.
    songs_with_genres = with_zuke_attachments(
      Song.includes(:artist, :album, :genres)
    ).where(id: song_ids)

    # Group the songs by genre for the view
    @grouped_genres = songs_with_genres
      .flat_map { |song| song.genres.map { |genre| [ genre, song ] } }
      .group_by { |genre, _song| genre }
      .transform_values { |genre_song_pairs| genre_song_pairs.map { |_, song| song } }
      .sort_by { |genre, _songs| genre.name }
      .to_h

    # Serialize through the presenter so the view renders the shared smart-image
    # component (previously it inlined its own markup and interpolated a raw
    # attachment). Every song here is already playable — the ranking joined the
    # preview attachment — so the presenter's filter is a second expression of
    # the same rule rather than a live guard.
    @genre_songs = @grouped_genres.transform_values do |songs|
      serialize_songs_for_player(songs).first
    end

    render partial: "zuke/turbo_frames/genres", formats: [ :html ]
  end

  # Renders the "About" section.
  def about
    render partial: "zuke/turbo_frames/about", formats: [ :html ]
  end

  # Renders a list of all songs for the current user context.
  def songs
    @songs = load_songs
    @songs_for_display, @songs_data = serialize_songs_for_player(@songs)

    render partial: "zuke/turbo_frames/index", formats: [ :html ]
  end

  # Performs a search across songs, artists, and albums, including SoundCloud.
  def search
    @query = params[:q].to_s.strip
    return if @query.length < 3

    # --- Local Search ---
    local_songs = perform_local_song_search(@query)
    @artists = perform_local_artist_search(@query)
    @albums = perform_local_album_search(@query)
    # --- End Local Search ---

    # --- SoundCloud Search ---
    soundcloud_songs = perform_soundcloud_search(@query)
    # --- End SoundCloud Search ---

    # --- Combine Results ---
    @songs = local_songs # For display in the "Songs" tab of results
    local_songs_data, = serialize_songs_for_player(local_songs)
    @songs_for_display = local_songs_data + soundcloud_songs
    @songs_data = @songs_for_display.to_json
    # --- End Combine Results ---

    render partial: "zuke/turbo_frames/search_results", formats: [ :html ]
  end

  # Fetches fresh data for a SoundCloud track, including a new stream URL.
  def refresh_soundcloud_track
    track_id = params[:id].to_s.gsub("soundcloud-", "")
    service = SoundCloudService.new
    track_data = service.get_track(track_id)

    if track_data
      render json: SoundCloudSongPresenter.new(track_data).to_song_hash
    else
      render json: { error: "Track not found" }, status: :not_found
    end
  end

  private

  # Establishes the base scope for songs based on user authentication.
  def base_songs_scope
    if zuke_admin?
      Song.all
    else
      # When users are implemented, this will correctly scope to public songs.
      # For now, if no songs are associated with users, it returns all songs.
      Song.left_joins(:users).where(users: { id: nil })
    end
  end

  # Loads all songs within the current scope with the associations and
  # attachments SongPresenter reads. Missing banner_video here meant a query per
  # song for every playable track on the main player.
  def load_songs
    with_zuke_attachments(base_songs_scope.includes(:album, :artist))
  end

  def perform_local_song_search(query)
    # .playable before .limit — the limit must apply to the songs that can
    # actually be played, or a search returns fewer than 10 results while more
    # playable matches exist behind the rejected rows.
    load_songs.playable
              .joins(:artist)
              .left_joins(:album)
              .where("songs.title ILIKE :q OR artists.name ILIKE :q OR albums.title ILIKE :q", q: "%#{query}%")
              .distinct
              .limit(10)
  end

  def perform_local_artist_search(query)
    Artist.ransack(name_cont: query).result
          .includes(:songs)
          .limit(5)
  end

  def perform_local_album_search(query)
    Album.ransack(title_cont: query).result
          .includes(:artist, :songs)
          .limit(5)
  end

  def perform_soundcloud_search(query)
    SoundCloudService.new.search(query).map do |track|
      SoundCloudSongPresenter.new(track).to_song_hash
    end
  end

  # Serializes a collection of Song objects for the Zuke player.
  #
  # Songs with no preview are dropped here rather than in each caller.
  # SongPresenter returns url: nil for them and the smart-image component renders
  # a play affordance unconditionally, so a song with no preview became a card
  # that dispatched an empty URL on click. Filtering in one place means every
  # caller is covered — earlier this guard was applied to three of the seven
  # callers and the main player kept the bug.
  #
  # @param songs [ActiveRecord::Relation<Song>, Array<Song>] songs to serialize
  # @return [Array(Array<Hash>, String)] A tuple containing the array of song
  #   hashes and the JSON representation of that array.
  def serialize_songs_for_player(songs)
    playable = songs.select(&:playable?)
    song_hashes = playable.map { |song| SongPresenter.new(song).to_song_hash }
    [ song_hashes, song_hashes.to_json ]
  end

  # Eager-loads everything SongPresenter reads from a song, blobs included.
  #
  # Expressed through Song::SERIALIZATION_INCLUDES rather than with_attached_*,
  # so there is one preload definition in the app instead of a second copy here
  # that can drift from the one PlaylistsController uses.
  #
  # @param relation [ActiveRecord::Relation<Song>] a Song relation
  def with_zuke_attachments(relation)
    relation.includes(Song::SERIALIZATION_INCLUDES)
  end

  # The includes hash for a collection of songs being serialized through
  # SongPresenter. Defined on the model so controllers that build their own
  # collections (PlaylistsController) preload the same set.
  def song_serialization_includes
    Song::SERIALIZATION_INCLUDES
  end
end
