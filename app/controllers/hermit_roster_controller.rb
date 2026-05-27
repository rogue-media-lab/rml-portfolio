class HermitRosterController < ApplicationController
  layout "hermit_plus"

  def index
    @hermits = Hermit.order(:alias)
    @crews = HermitCrew.where(season: 8)

    if params[:crew].present?
      crew = HermitCrew.find_by(slug: params[:crew])
      @hermits = crew.hermits.order(:alias) if crew
    end
  end

  def show
    @hermit = Hermit.find_by!(slug: params[:slug])
    @videos = @hermit.hermit_videos.where(season: 8).order(:episode)
    @crews = @hermit.hermit_crews.where(season: 8)
  end
end
