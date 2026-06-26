class SaltAndTarController < ApplicationController
  def index; end

  def archive
    @videos = SaltAndTarVideo.where(published: true).order(:position)
    @selected_video = @videos.first
  end

  def booking; end
end
