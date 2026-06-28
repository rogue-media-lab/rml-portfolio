module CarUs
  class PagesController < BaseController
    def home
      # Public landing page — shop directory
      @shops = CarUs::Shop.where(active: true).order(:name)
    end
  end
end