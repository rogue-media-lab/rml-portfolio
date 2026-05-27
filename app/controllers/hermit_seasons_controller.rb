class HermitSeasonsController < ApplicationController
  layout "hermit_plus"

  def home
    @hermits = Hermit.order(:alias)
    @crews = HermitCrew.where(season: 8).includes(:hermits)
    @first_episodes = HermitVideo.where(season: 8, episode: 1).includes(:hermit)
  end
end
