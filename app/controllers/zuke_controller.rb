# frozen_string_literal: true

# The ZukeController handles all requests related to the Zuke music player.
# It is responsible for serving the main player interface, as well as handling
# requests for artists, albums, genres, and search functionality.
class ZukeController < ApplicationController
  include ZukeAuth

  def index; end

  # Serves the main music player interface, loading all applicable songs.
  def music
    local_songs = load_songs
    @songs_for_display, @songs_data = serialize_songs_for_player(local_songs)
  end

  # Renders the list of all artists, grouped by the first letter of their name.
  def artists
    @artists = Artist.includes(:songs).order(:name)
    @grouped_artists = @artists.group_by { |a| a.name.first.upcase }

    render partial: "zuke/turbo_frames/artists", formats: [ :html ]
  end

  # Renders the list of all albums, grouped by the first letter of their title.
  def albums
    @albums = Album.includes(:artist, :songs)
                   .order(:title)
                   .group_by { |a| a.title.first.upcase }

    render partial: "zuke/turbo_frames/albums", formats: [ :html ]
  end

  # Renders a list of genres, each with a sample of associated songs.
  def genres
    # This SQL query uses a window function to find the top 20 songs for each genre
    # without causing an N+1 query. It's significantly more performant.
    sql = <<-SQL
      SELECT id FROM (
        SELECT
          s.id,
          sg.genre_id,
          ROW_NUMBER() OVER(PARTITION BY sg.genre_id ORDER BY s.created_at DESC) as rn
        FROM songs s
        INNER JOIN song_genres sg ON s.id = sg.song_id
      ) ranked_songs
      WHERE rn <= 20
    SQL

    song_ids = ActiveRecord::Base.connection.execute(sql).pluck("id")

    # Eager load the songs and their associations
    songs_with_genres = Song.includes(:artist, :album, :genres)
                            .where(id: song_ids)

    # Group the songs by genre for the view
    @grouped_genres = songs_with_genres
      .flat_map { |song| song.genres.map { |genre| [ genre, song ] } }
      .group_by { |genre, _song| genre }
      .transform_values { |genre_song_pairs| genre_song_pairs.map { |_, song| song } }
      .sort_by { |genre, _songs| genre.name }
      .to_h

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

  # Loads all songs within the current scope with necessary associations.
  def load_songs
    base_songs_scope.includes(:album, :artist)
                    .with_attached_image
                    .with_attached_audio_file
                    .with_attached_waveform_data
  end

  def perform_local_song_search(query)
    load_songs.joins(:artist)
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
  # @param songs [ActiveRecord::Relation<Song>] The songs to serialize.
  # @return [Array(Array<Hash>, String)] A tuple containing the array of song
  #   hashes and the JSON representation of that array.
  def serialize_songs_for_player(songs)
    song_hashes = songs.map { |song| SongPresenter.new(song).to_song_hash }
    [ song_hashes, song_hashes.to_json ]
  end
end
