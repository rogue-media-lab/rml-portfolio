module CarUs
  class TechProfilesController < CarUs::BaseController
    before_action :authenticate_technician!
    layout "car_us/technician"

    def show
    end
  end
end