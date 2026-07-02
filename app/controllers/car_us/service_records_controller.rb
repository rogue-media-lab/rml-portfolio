module CarUs
  class ServiceRecordsController < CarUs::BaseController
    before_action :authenticate_car_owner!
    before_action :set_vehicle

    def index
      @service_records = @vehicle.service_records.recent
    end

    private

    def set_vehicle
      @vehicle = current_car_owner.vehicles.find(params[:vehicle_id])
    end
  end
end
