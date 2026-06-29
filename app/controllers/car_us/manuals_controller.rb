module CarUs
  class ManualsController < CarUs::BaseController
    before_action :authenticate_car_owner!
    before_action :set_vehicle

    def show
    end

    private

    def set_vehicle
      @vehicle = current_car_owner.vehicles.find(params[:vehicle_id])
    end
  end
end