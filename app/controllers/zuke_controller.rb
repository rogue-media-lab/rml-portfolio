class ZukeController < ApplicationController
  def index; end

  def music
    if current_user
      # @songs = Song.left_joins(:users).where(users: { id: nil })
      #              .includes(:album, :artist)
      #              .with_attached_image
      #              .with_attached_audio_file
      @songs = current_user.songs.includes(:album, :artist)
                           .with_attached_image
                           .with_attached_audio_file
      if @songs.empty?
        redirect_to root_path, notice: "No songs found for the current user."
        return
      end

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

    @songs_data = @songs.map do |song|
      {
        id: song.id,
        url: song.audio_file.attached? ? url_for(song.audio_file) : nil,
        title: song.title,
        artist: song.artist.name,
        banner: song.image.attached? ? url_for(song.image) : nil,
        bannerMobile: song.image.attached? ? url_for(song.mobile_image_variant) : nil,
        imageCredit: song.image_credit,
        imageCreditUrl: song.image_credit_url,
        imageLicense: song.image_license,
        audioSource: song.audio_source,
        audioLicense: song.audio_license,
        additionalCredits: song.additional_credits
      }
    end.to_json
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
end
