class HermitVideosController < ApplicationController
  layout "hermit_plus"

  def show
    @video = HermitVideo.find(params[:id])
    @hermit = @video.hermit
    @appearing_hermits = @video.appearing_hermits
  end

  def watch
    @video = HermitVideo.find(params[:id])
  end
end
