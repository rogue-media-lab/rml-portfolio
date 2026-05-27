class HermitCrewsController < ApplicationController
  layout "hermit_plus"

  def index
    @hermit_crews = HermitCrew.where(season: 8).includes(:hermits)
  end

  def show
    @crew = HermitCrew.find_by!(slug: params[:slug])
    @hermits = @crew.hermits.order(:alias)
    @videos = HermitVideo.where(hermit: @hermits, season: 8).includes(:hermit).order(:hermit_id, :episode)
  end
end
