module CarUs
  class TechLookupsController < CarUs::BaseController
    before_action :authenticate_technician!
    layout "car_us/technician"

    def index
    end

    def show
    end

    def customer_lookup
    end
  end
end