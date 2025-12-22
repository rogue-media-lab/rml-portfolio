require "ostruct"

class PlaylistsController < ApplicationController
  before_action :set_playlist, only: [ :show ]

  # GET /playlists
  # Shows all playlists, including a virtual one for SoundCloud likes
  def index
    local_playlists = Playlist.includes(:songs).order(:name)

    # Get the song count for SoundCloud Likes, using a 15-minute cache
    soundcloud_likes_count = Rails.cache.fetch("soundcloud_likes_count", expires_in: 15.minutes) do
      SoundcloudLikesService.fetch_likes.count
    end

    # Create a virtual playlist for SoundCloud Likes
    soundcloud_likes_playlist = OpenStruct.new(
      id: "soundcloud-likes",
      name: "SoundCloud Likes",
      description: "Songs I've liked on SoundCloud.",
      songs: [], # This avoids loading all songs on the index page
      song_count: soundcloud_likes_count
    )

    @playlists = [ soundcloud_likes_playlist ] + local_playlists
    render layout: false if turbo_frame_request?
  end

  # GET /playlists/:id
  # Shows songs in a specific playlist, including the virtual SoundCloud likes playlist
  def show
    if @playlist.id == "soundcloud-likes"
      soundcloud_likes = SoundcloudLikesService.fetch_likes
      @songs = soundcloud_likes.map do |like|
        track = like["track"]
        next if track.blank? # Skip if the track object is missing

        SoundCloudSongPresenter.new(track).to_song_hash
      end.compact # Remove any nil entries from skipped tracks
      @songs_data = @songs.to_json
    else
      @songs = @playlist.ordered_songs.includes(
        :artist, :album,
        { audio_file_attachment: :blob },
        { image_attachment: :blob }, # For mobile_image_variant
        :banner_video_attachment,
        { waveform_data_attachment: :blob }
      )
      # @songs_data will be generated in the view for local playlists
    end
    render layout: false if turbo_frame_request?
  end

  private

  def set_playlist
    if params[:id] == "soundcloud-likes"
      @playlist = OpenStruct.new(
        id: "soundcloud-likes",
        name: "SoundCloud Likes",
        description: "Songs I've liked on SoundCloud.",
        songs: []
      )
    else
      @playlist = Playlist.find(params[:id])
    end
  end

  def turbo_frame_request?
    request.headers["Turbo-Frame"].present?
  end
end
