require "ostruct"

class PlaylistsController < ApplicationController
  include ZukeAuth

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
      # .playable — the same rule every other caller uses, so an unplayable song
      # cannot reach the player here either. Song::SERIALIZATION_INCLUDES
      # preloads the blobs the presenter reads ({ attachment: :blob }); a bare
      # :banner_video_attachment would still fire a query per song.
      # The same rule a third time: a signed-in listener — admin or user — may be entitled
      # to the full track, so both the preloads and the presenter take the listener. A
      # signed-out visitor gets the master-free list and the preview, exactly as before.
      listener = zuke_listener
      song_records = @playlist.ordered_songs.playable.includes(
        listener ? Song::FULL_AUDIO_INCLUDES : Song::SERIALIZATION_INCLUDES
      )

      @songs = song_records.map { |song| SongPresenter.new(song, listener: listener).to_song_hash }
      @songs_data = @songs.to_json
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
