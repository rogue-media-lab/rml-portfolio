module CarUs
  class VehiclesController < CarUs::BaseController
    before_action :authenticate_car_owner!

    def index
      @vehicles = current_car_owner.vehicles.order(created_at: :desc)
    end

    def show
      @vehicle = current_car_owner.vehicles.find(params[:id])
    end

    def new
      @vehicle = current_car_owner.vehicles.build
    end

    def create
      @vehicle = current_car_owner.vehicles.build(vehicle_params)

      # If VIN provided but year/make/model are blank, try NHTSA decode
      if @vehicle.vin.present? && (@vehicle.year.blank? || @vehicle.make.blank?)
        decoded = CarUs::Vehicle.decode_vin(@vehicle.vin)
        if decoded
          @vehicle.assign_attributes(decoded.slice(:year, :make, :model, :trim, :engine_size, :transmission))
        end
      end

      if @vehicle.save
        redirect_to vehicles_path, notice: "Vehicle added to your garage."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def vehicle_params
      params.require(:car_us_vehicle).permit(
        :vin, :year, :make, :model, :trim, :engine_size, :transmission, :mileage
      )
    end
  end
end
