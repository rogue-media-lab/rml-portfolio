class PlaylistsController < ApplicationController
  before_action :set_playlist, only: [ :show ]

  # GET /playlists
  # Shows all playlists
  def index
    @playlists = Playlist.includes(:songs).order(:name)
    render layout: false if turbo_frame_request?
  end

  # GET /playlists/:id
  # Shows songs in a specific playlist
  def show
    @songs = @playlist.ordered_songs.includes(:artist, :album, image_attachment: :blob)
    render layout: false if turbo_frame_request?
  end

  private

  def set_playlist
    @playlist = Playlist.find(params[:id])
  end

  def turbo_frame_request?
    request.headers["Turbo-Frame"].present?
  end
end
