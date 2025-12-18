# Hermit Videos Controller for Milk Admin
class MilkAdmin::HermitVideosController < ApplicationController
  before_action :authenticate_milk_admin!
  before_action :set_hermit_video, only: [ :edit, :update, :destroy ]
  before_action :set_hermits, only: [ :new, :create, :edit, :update ]

  def index
    redirect_to milk_admin_hermit_videos_dashboard_path, status: :see_other
  end

  def dashboard
    @hermit_videos = HermitVideo.all.includes(:hermit)
    render layout: false if turbo_frame_request?
  end

  def new
    @hermit_video = HermitVideo.new
    render layout: false if turbo_frame_request?
  end

  def edit
    render layout: false if turbo_frame_request?
  end

  def create
    @hermit_video = HermitVideo.new(hermit_video_params)

    respond_to do |format|
      if @hermit_video.save
        redirect_path = turbo_frame_request? ? milk_admin_hermit_videos_dashboard_path : @hermit_video
        format.html { redirect_to redirect_path, notice: 'Hermit video was successfully created.' }
        format.json { render :show, status: :created, location: @hermit_video }
      else
        format.html { render :new, status: :unprocessable_entity, layout: !turbo_frame_request? }
        format.json { render json: @hermit_video.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @hermit_video.update(hermit_video_params)
        redirect_path = turbo_frame_request? ? milk_admin_hermit_videos_dashboard_path : @hermit_video
        format.html { redirect_to redirect_path, notice: 'Hermit video was successfully updated.' }
        format.json { render :show, status: :ok, location: @hermit_video }
      else
        format.html { render :edit, status: :unprocessable_entity, layout: !turbo_frame_request? }
        format.json { render json: @hermit_video.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @hermit_video.destroy
    respond_to do |format|
      format.html { redirect_to milk_admin_hermit_videos_dashboard_path, notice: 'Hermit video was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  def set_hermit_video
    @hermit_video = HermitVideo.find(params[:id])
  end

  def set_hermits
    @hermits = Hermit.all.order(:alias)
  end

  def hermit_video_params
    params.require(:hermit_video).permit(:youtube_video_id, :thumbnail_url, :title, :season, :episode, :hermit_id)
  end
end
