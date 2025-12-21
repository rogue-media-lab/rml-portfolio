class ZukeController < ApplicationController
  def index; end

  def music
    # 1. Load local songs from the database
    local_songs = if current_user
      current_user.songs.includes(:album, :artist)
                           .with_attached_image
                           .with_attached_audio_file
    elsif current_milk_admin
      Song.includes(:album, :artist)
                   .with_attached_image
                   .with_attached_audio_file
    else
      Song.left_joins(:users).where(users: { id: nil })
                   .includes(:album, :artist)
                   .with_attached_image
                   .with_attached_audio_file
    end

    # 2. Format local songs into a standard hash
    local_song_hashes = local_songs.map do |song|
      {
        id: song.id,
        url: song.audio_file.attached? ? rails_blob_url(song.audio_file) : nil,
        title: song.title,
        artist: song.artist.name,
        banner: song.image.attached? ? rails_blob_url(song.image) : nil,
        bannerMobile: song.image.attached? ? rails_blob_url(song.mobile_image_variant) : nil,
        bannerVideo: song.banner_video.attached? ? rails_blob_url(song.banner_video) : nil,
        imageCredit: song.image_credit,
        imageCreditUrl: song.image_credit_url,
        imageLicense: song.image_license,
        audioSource: song.audio_source,
        audioLicense: song.audio_license,
        additionalCredits: song.additional_credits,
        waveformUrl: nil, # Local songs don't have a pre-generated waveform from an API
        duration: song.audio_file.attached? ? (song.audio_file.metadata["duration"] || 0) : 0
      }
    end

    # 3. Create a unified list for the view and the player
    @songs_for_display = local_song_hashes
    @songs_data = @songs_for_display.to_json
  end

  def artists
    @artists = Artist.includes(:songs).order(:name)
    @grouped_artists = @artists.group_by { |a| a.name.first.upcase }

    render partial: "zuke/turbo_frames/artists", formats: [ :html ]
  end

  def albums
    # Load albums with their artists and songs
    @albums = Album.includes(:artist, :songs)
                   .order(:title)
                   .group_by { |a| a.title.first.upcase }

    render partial: "zuke/turbo_frames/albums", formats: [ :html ]
  end

  # app/controllers/music_controller.rb
  def genres
    # Group songs by genre, including songs without a genre
    @grouped_genres = Genre.left_joins(:songs)
                          .where.not(songs: { id: nil })
                          .distinct
                          .sort_by(&:name)
                          .map { |genre| [ genre, genre.songs.includes(:artist, :album).limit(20) ] }
                          .to_h

    # For songs without a genre (if needed)
    # songs_without_genre = Song.where(genre_id: nil)
    # @grouped_genres["Unknown"] = songs_without_genre if songs_without_genre.any?
    render partial: "zuke/turbo_frames/genres", formats: [ :html ]
  end

  def about
    render partial: "zuke/turbo_frames/about", formats: [ :html ]
  end

  def songs
    if current_user
      @songs = current_user.songs.includes(:album, :artist)
                           .with_attached_image
                           .with_attached_audio_file
    elsif current_milk_admin
      @songs = Song.includes(:album, :artist)
                   .with_attached_image
                   .with_attached_audio_file
    else
      @songs = Song.left_joins(:users).where(users: { id: nil })
                   .includes(:album, :artist)
                   .with_attached_image
                   .with_attached_audio_file
    end
    @songs_for_display = @songs.map do |song|
      {
        id: song.id,
        url: song.audio_file.attached? ? rails_blob_url(song.audio_file) : nil,
        title: song.title,
        artist: song.artist.name,
        banner: song.image.attached? ? rails_blob_url(song.image) : nil,
        bannerMobile: song.image.attached? ? rails_blob_url(song.mobile_image_variant) : nil,
        bannerVideo: song.banner_video.attached? ? rails_blob_url(song.banner_video) : nil,
        imageCredit: song.image_credit,
        imageCreditUrl: song.image_credit_url,
        imageLicense: song.image_license,
        audioSource: song.audio_source,
        audioLicense: song.audio_license,
        additionalCredits: song.additional_credits,
        waveformUrl: nil,
        duration: song.audio_file.attached? ? (song.audio_file.metadata["duration"] || 0) : 0
      }
    end
    @songs_data = @songs_for_display.to_json

    render partial: "zuke/turbo_frames/index", formats: [ :html ]
  end

  def search
    @query = params[:q]
    query = @query

    # Return empty results if query is blank or too short
    if query.blank? || query.length < 3
      @songs = []
      @artists = []
      @albums = []
      render partial: "zuke/turbo_frames/search_results", formats: [ :html ]
      return
    end

    # Get base songs with proper scoping based on user
    base_songs = if current_user
      current_user.songs
    elsif current_milk_admin
      Song.all
    else
      Song.left_joins(:users).where(users: { id: nil })
    end

    # Search local songs by title, artist name, or album title
    local_songs = base_songs.joins(:artist)
                            .left_joins(:album)
                            .where(
                              "songs.title ILIKE :query OR artists.name ILIKE :query OR albums.title ILIKE :query",
                              query: "%#{query}%"
                            )
                            .includes(:album, :artist)
                            .with_attached_image
                            .with_attached_audio_file
                            .distinct
                            .limit(10)

    # --- SoundCloud Search ---
    soundcloud_service = SoundCloudService.new
    soundcloud_tracks = soundcloud_service.search(query)
    soundcloud_songs = soundcloud_tracks.map do |track|
      SoundCloudSongPresenter.new(track).to_song_hash
    end
    # --- End SoundCloud Search ---


    # Use Ransack for artists and albums
    @artists_q = Artist.ransack(name_cont: query)
    @albums_q = Album.ransack(title_cont: query)

    @artists = @artists_q.result
                         .includes(:songs)
                         .limit(5)

    @albums = @albums_q.result
                       .includes(:artist, :songs)
                       .limit(5)

    # Prepare local songs data for player
    local_songs_data = local_songs.map do |song|
      {
        id: song.id,
        url: song.audio_file.attached? ? rails_blob_url(song.audio_file) : nil,
        title: song.title,
        artist: song.artist.name,
        banner: song.image.attached? ? rails_blob_url(song.image) : nil,
        bannerMobile: song.image.attached? ? rails_blob_url(song.mobile_image_variant) : nil,
        bannerVideo: song.banner_video.attached? ? rails_blob_url(song.banner_video) : nil,
        imageCredit: song.image_credit,
        imageCreditUrl: song.image_credit_url,
        imageLicense: song.image_license,
        audioSource: song.audio_source,
        audioLicense: song.audio_license,
        additionalCredits: song.additional_credits,
        waveformUrl: nil,
        duration: song.audio_file.attached? ? (song.audio_file.metadata["duration"] || 0) : 0
      }
    end

    # --- Combine Results ---
    @songs = local_songs
    @songs_for_display = local_songs_data + soundcloud_songs
    @songs_data = @songs_for_display.to_json
    # --- End Combine Results ---

    render partial: "zuke/turbo_frames/search_results", formats: [ :html ]
  end

  # GET /zuke/refresh_soundcloud_track/:id
  # Fetches fresh data for a SoundCloud track, including a new stream URL.
  def refresh_soundcloud_track
    track_id = params[:id].to_s.gsub("soundcloud-", "")
    service = SoundCloudService.new
    track_data = service.get_track(track_id)

    if track_data
      song_hash = SoundCloudSongPresenter.new(track_data).to_song_hash
      render json: song_hash
    else
      render json: { error: "Track not found" }, status: :not_found
    end
  end
end
