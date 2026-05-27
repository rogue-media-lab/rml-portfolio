# Hermit Videos Controller for Milk Admin
class MilkAdmin::HermitVideosController < ApplicationController
  before_action :authenticate_milk_admin!
  before_action :set_hermit_video, only: [ :edit, :update, :destroy ]
  before_action :set_hermits, only: [ :new, :create, :edit, :update ]

  def index
    redirect_to milk_admin_hermit_videos_dashboard_path, status: :see_other
  end

  def dashboard
    @hermit_videos = HermitVideo.includes(:hermit)

    # Filter by hermit
    if params[:hermit_id].present?
      @hermit_videos = @hermit_videos.where(hermit_id: params[:hermit_id])
      @selected_hermit = Hermit.find_by(id: params[:hermit_id])
    end

    # Filter by health
    if params[:health] == "bad"
      @hermit_videos = @hermit_videos.where("thumbnail_url IS NULL OR thumbnail_url = '' OR youtube_video_id IS NULL OR youtube_video_id = ''")
    end

    @hermit_videos = @hermit_videos.order(season: :desc, episode: :desc)

    # All hermits for filter dropdown
    @filter_hermits = Hermit.order(:alias)

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
        format.html { redirect_to redirect_path, notice: "Hermit video was successfully created." }
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
        format.html { redirect_to redirect_path, notice: "Hermit video was successfully updated." }
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
      format.html { redirect_to milk_admin_hermit_videos_dashboard_path, notice: "Hermit video was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # YouTube Fetch: Show the form to input a YouTube channel URL
  def fetch
    render layout: false if turbo_frame_request?
  end

  # YouTube Fetch: Process the channel URL and present suggestions
  def fetch_results
    @channel_input = params[:channel_url]
    @max_results = (params[:max_results] || 10).to_i

    if @channel_input.blank?
      redirect_to milk_admin_fetch_hermit_videos_path, alert: "Please provide a YouTube channel URL or ID."
      return
    end

    begin
      channel_id = YoutubeService.resolve_channel_id(@channel_input)

      if channel_id.blank?
        redirect_to milk_admin_fetch_hermit_videos_path, alert: "Could not resolve a valid YouTube channel ID from that input."
        return
      end

      @suggestions = YoutubeService.search_channel_videos(channel_id, max_results: @max_results)

      if @suggestions.empty?
        redirect_to milk_admin_fetch_hermit_videos_path, alert: "No videos found for that channel. Check the URL and try again."
        return
      end

      # Fetch full details for better thumbnails
      video_ids = @suggestions.map { |s| s[:video_id] }.compact
      @details = YoutubeService.video_details(video_ids) if video_ids.any?

      # Merge details into suggestions for display
      @suggestions.each do |suggestion|
        detail = @details&.dig(suggestion[:video_id])
        if detail
          suggestion[:thumbnail_url] = detail[:thumbnail_url] if detail[:thumbnail_url].present?
          suggestion[:duration] = detail[:duration]
          suggestion[:view_count] = detail[:view_count]
        end
      end

      @hermits = Hermit.all.order(:alias)
      render layout: false if turbo_frame_request?
    rescue YoutubeService::QuotaExceeded
      redirect_to milk_admin_fetch_hermit_videos_path, alert: "YouTube API quota exceeded. Try again tomorrow or check your API key."
    rescue YoutubeService::InvalidKey
      redirect_to milk_admin_fetch_hermit_videos_path, alert: "Invalid YouTube API key. Check your YOUTUBE_API_KEY environment variable."
    rescue YoutubeService::Error => e
      redirect_to milk_admin_fetch_hermit_videos_path, alert: "YouTube API error: #{e.message}"
    end
  end

  # Create multiple videos from fetch results
  def bulk_create
    videos_params = params[:videos] || []
    created = 0
    skipped = 0

    videos_params.each do |_, video_data|
      next unless video_data["selected"] == "1"

      hermit = Hermit.find_by(id: video_data["hermit_id"])
      next unless hermit

      youtube_id = video_data["youtube_video_id"]

      # Skip if already exists
      if HermitVideo.exists?(youtube_video_id: youtube_id)
        skipped += 1
        next
      end

      HermitVideo.create!(
        hermit: hermit,
        youtube_video_id: youtube_id,
        title: video_data["title"],
        thumbnail_url: video_data["thumbnail_url"],
        season: video_data["season"].to_i,
        episode: video_data["episode"].to_i
      )
      created += 1
    end

    redirect_to milk_admin_hermit_videos_dashboard_path, notice: "Created #{created} videos. Skipped #{skipped} duplicates."
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
