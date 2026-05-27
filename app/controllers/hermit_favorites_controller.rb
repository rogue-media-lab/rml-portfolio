class HermitFavoritesController < ApplicationController
  before_action :authenticate_user!
  layout "hermit_plus"

  def index
    @favorites = current_user.favorites.includes(hermit_video: [ :hermit ]).order(created_at: :desc)
  end

  def create
    video = HermitVideo.find(params[:video_id])

    favorite = current_user.favorites.build(hermit_video: video)

    if favorite.save
      flash[:notice] = "Added to favorites"
    else
      flash[:alert] = "Already in favorites"
    end

    redirect_back(fallback_location: hermit_plus_home_path)
  end

  def destroy
    video = HermitVideo.find(params[:video_id])
    favorite = current_user.favorites.find_by(hermit_video: video)

    if favorite&.destroy
      flash[:notice] = "Removed from favorites"
    else
      flash[:alert] = "Not in favorites"
    end

    redirect_back(fallback_location: hermit_plus_home_path)
  end
end
