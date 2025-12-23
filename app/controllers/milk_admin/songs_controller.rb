# Blog Controller for Milk Admin
class MilkAdmin::SongsController < ApplicationController
  include ZukeAuth
  # Ensure milk admin is logged in for CRUD actions
  before_action :authenticate_zuke_admin!
  # Set song for methods that need it
  before_action :set_song, only: [ :edit, :update, :destroy, :destroy_image, :destroy_file, :destroy_banner_video ]

  # GET /milk_admin/songs
  #
  # Returns all songs. The `format.html` response is the default view for
  # this controller and is used for the index page of the milk admin dashboard.
  # The `format.json` response is used by the JavaScript frontend to populate the data tables.
  def index
    @songs = Song.with_attached_image.all
    respond_to do |format|
      format.html
      format.json { render json: @songs.as_json(
        only: [ :id, :artist, :album, :title ]
      )}
    end
  end

  def dashboard
    @songs = Song.includes(:artist, { album: :genre }, :genres).order(created_at: :desc)

    # Overview metrics
    @total_songs = Song.count
    @total_artists = Artist.count
    @total_albums = Album.count
    @total_genres = Genre.count

    # Songs this month with trend
    @songs_this_month = Song.where("created_at >= ?", Time.current.beginning_of_month).count
    last_month_start = 1.month.ago.beginning_of_month
    last_month_end = 1.month.ago.end_of_month
    @songs_last_month = Song.where(created_at: last_month_start..last_month_end).count
    @song_trend = calculate_trend(@songs_last_month, @songs_this_month)

    # Completion metrics
    @songs_with_audio = Song.joins(:audio_file_attachment).count
    @songs_with_image = Song.joins(:image_attachment).count
    @songs_complete = Song.joins(:audio_file_attachment, :image_attachment).count
    @songs_incomplete = @total_songs - @songs_complete

    # Top lists
    @top_artists = Artist.joins(:songs)
                         .group(:id)
                         .order("COUNT(songs.id) DESC")
                         .limit(5)
                         .select("artists.*, COUNT(songs.id) as songs_count")

    @top_genres = Genre.joins(:songs)
                       .group(:id)
                       .order("COUNT(songs.id) DESC")
                       .limit(5)
                       .select("genres.*, COUNT(songs.id) as songs_count")

    render layout: false if turbo_frame_request?
  end

  # GET /milk_admin/songs/new
  #
  # Initializes a new Song object.
  # The `new` action is used to display a form for creating a new song.

  def new
    @song = Song.new
    @users = User.all
    @song.build_artist
    album = @song.build_album
    album.build_genre

    render layout: false if turbo_frame_request?
  end

  def edit
    @users = User.all
    # Build missing associations so form fields render
    @song.build_artist unless @song.artist
    unless @song.album
      @song.build_album
      @song.album.build_genre
    else
      @song.album.build_genre unless @song.album.genre
    end

    render layout: false if turbo_frame_request?
  end

  # POST /milk_admin/songs
  #
  # Creates a new song using provided song parameters.
  #
  # On success:
  # - Sets the image URL if an image is attached.
  # - Sets the file URL if a file is attached.
  # - Redirects to the songs listing page with a success notice.
  # - Renders the blog as JSON with a 201 status code.
  #
  # On failure:
  # - Renders the new song form with an unprocessable entity status.
  # - Renders the errors as JSON with an unprocessable entity status.

  def create
    @song = Song.new(song_params)

    respond_to do |format|
      if @song.save
        redirect_path = turbo_frame_request? ? milk_admin_songs_dashboard_path : milk_admin_songs_path
        format.html { redirect_to redirect_path, notice: "Song was successfully added." }
        format.json { render json: @song }
      else
        format.html { render :new, status: :unprocessable_entity, layout: !turbo_frame_request? }
        format.json { render json: @song.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /milk_admin/songs/1
  #
  # Updates a song using the given song parameters.
  #
  # On success:
  # - Sets the image URL if an image is attached.
  # - Sets the file URL if a file is attached.
  # - Redirects to the songs listing page with a success notice.
  # - Renders the song as JSON with a 201 status code.
  #
  # On failure:
  # - Renders the new song form with an unprocessable entity status.
  # - Renders the errors as JSON with an unprocessable entity status.
  def update
    respond_to do |format|
      if @song.update(song_params)
        redirect_path = turbo_frame_request? ? milk_admin_songs_dashboard_path : milk_admin_songs_path
        format.html { redirect_to redirect_path, notice: "Song was successfully updated." }
        format.json { render :show, status: :ok, location: @song }
      else
        @users = User.all
        format.html { render :edit, status: :unprocessable_entity, layout: !turbo_frame_request? }
        format.json { render json: @song.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /milk_admin/songs/1
  #
  # Destroys a song any associated file and any associated image.
  #
  # On success:
  # - Redirects to the songs listing page with a success notice.
  # - Renders the song as JSON with a 204 status code.
  #
  # On failure:
  # - Renders the new song form with an unprocessable entity status.
  # - Renders the errors as JSON with an unprocessable entity status.
  def destroy
    respond_to do |format|
      if @song.destroy
        redirect_path = turbo_frame_request? ? milk_admin_songs_dashboard_path : milk_admin_songs_path
        format.html { redirect_to redirect_path, status: :see_other, notice: "Song, file and image were successfully destroyed." }
        format.json { head :no_content }
      else
        redirect_path = turbo_frame_request? ? milk_admin_songs_dashboard_path : milk_admin_songs_path
        format.html { redirect_to redirect_path, alert: "Failed to destroy the song." }
        format.json { render json: @song.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /milk_admin/songs/1/destroy_image
  #
  # Destroys the associated image from the song - aws-s3.
  #
  # On success:
  # - Redirects to the edit page of the song with a success notice.
  # - Renders the song as JSON with a 204 status code.
  #
  # On failure:
  # - Renders the edit page of the song with an unprocessable entity status.
  # - Renders the errors as JSON with an unprocessable entity status.
  def destroy_image
    @song.image.purge_later

    respond_to do |format|
      if @song.image.attached?
        format.html { redirect_to edit_milk_admin_song_path(@song) }
        format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id(@song, "image")) }
      else
        format.html { redirect_to edit_milk_admin_song_path(@song), alert: "No image to remove." }
      end
    end
  end

  def destroy_banner_video
    @song.banner_video.purge_later

    respond_to do |format|
      if @song.banner_video.attached?
        format.html { redirect_to edit_milk_admin_song_path(@song), notice: "Banner video removed." }
      else
        format.html { redirect_to edit_milk_admin_song_path(@song), alert: "No banner video to remove." }
      end
    end
  end

  # DELETE /milk_admin/songs/1/destroy_file
  #
  # Destroys the associated audio file from the song - aws-s3.
  #
  # On success:
  # - Redirects to the edit page of the song with a success notice.
  # - Renders the song as JSON with a 204 status code.
  #
  # On failure:
  # - Renders the edit page of the song with an unprocessable entity status.
  # - Renders the errors as JSON with an unprocessable entity status.
  def destroy_file
    @song.audio_file.purge_later

    respond_to do |format|
      if @song.audio_file.attached?
        format.html { redirect_to edit_milk_admin_song_path(@song) }
        format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id(@song, "audio_file")) }
      else
        format.html { redirect_to edit_milk_admin_song_path(@song), alert: "No file to remove." }
      end
    end
  end

  private

  # Strong parameters method for song attributes.
  #
  # Ensures only the permitted attributes are allowed from the params hash.
  #
  # @return [ActionController::Parameters] filtered parameters for creating or updating a song.

  def song_params
    params.require(:song).permit(:image,
                                  :audio_file,
                                  :banner_video,
                                  :title,
                                  :focal_point_x,
                                  :focal_point_y,
                                  :image_credit,
                                  :image_credit_url,
                                  :image_license,
                                  :audio_source,
                                  :audio_license,
                                  :additional_credits,
                                  user_ids: [],
                                  artist_attributes: [ :id, :name ],
                                  album_attributes: [ :id, :title, genre: [ :name ] ])
  end

  # Finds the song with the given id and assigns it to the @song instance variable.
  #
  # This method is called by the before_action callback in the SongController and
  # is used by multiple actions in the controller to fetch the song related to
  # the current request.
  def set_song
    @song = Song.find(params[:id])
  end

  # Calculate percentage trend between two periods
  def calculate_trend(last_period, current_period)
    return 0 if last_period.zero?
    ((current_period - last_period).to_f / last_period * 100).round(1)
  end
end
