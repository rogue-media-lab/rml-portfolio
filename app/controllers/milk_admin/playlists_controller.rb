class MilkAdmin::PlaylistsController < ApplicationController
  before_action :authenticate_milk_admin!
  before_action :set_playlist, only: [ :show, :edit, :update, :destroy, :add_song, :remove_song ]

  def index
    @playlists = Playlist.includes(:songs).order(created_at: :desc)
  end

  def show
    @available_songs = Song.includes(:artist, :album).order("artists.name ASC, songs.title ASC")
                           .joins(:artist)
                           .where.not(id: @playlist.songs.pluck(:id))
  end

  def new
    @playlist = Playlist.new
  end

  def edit
    @available_songs = Song.includes(:artist, :album).order("artists.name ASC, songs.title ASC")
                           .joins(:artist)
                           .where.not(id: @playlist.songs.pluck(:id))
  end

  def create
    @playlist = Playlist.new(playlist_params)

    if @playlist.save
      redirect_to milk_admin_playlists_path, notice: "Playlist was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @playlist.update(playlist_params)
      redirect_to milk_admin_playlists_path, notice: "Playlist was successfully updated."
    else
      @available_songs = Song.includes(:artist, :album).order("artists.name ASC, songs.title ASC")
                             .joins(:artist)
                             .where.not(id: @playlist.songs.pluck(:id))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @playlist.destroy
    redirect_to milk_admin_playlists_path, status: :see_other, notice: "Playlist was successfully deleted."
  end

  # POST /milk_admin/playlists/:id/add_song
  def add_song
    song = Song.find(params[:song_id])

    unless @playlist.songs.include?(song)
      @playlist.playlist_songs.create(song: song)
      redirect_to edit_milk_admin_playlist_path(@playlist), notice: "Song added to playlist."
    else
      redirect_to edit_milk_admin_playlist_path(@playlist), alert: "Song is already in playlist."
    end
  end

  # DELETE /milk_admin/playlists/:id/remove_song/:song_id
  def remove_song
    playlist_song = @playlist.playlist_songs.find_by(song_id: params[:song_id])

    if playlist_song
      playlist_song.destroy
      redirect_to edit_milk_admin_playlist_path(@playlist), notice: "Song removed from playlist."
    else
      redirect_to edit_milk_admin_playlist_path(@playlist), alert: "Song not found in playlist."
    end
  end

  private

  def set_playlist
    @playlist = Playlist.find(params[:id])
  end

  def playlist_params
    params.require(:playlist).permit(:name, :description)
  end
end
