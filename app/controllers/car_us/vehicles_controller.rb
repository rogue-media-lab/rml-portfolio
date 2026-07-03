module CarUs
  class VehiclesController < CarUs::BaseController
    before_action :authenticate_car_owner!

    def index
      @vehicles = current_car_owner.vehicles.order(created_at: :desc)
    end

    def show
      @vehicle = current_car_owner.vehicles.find(params[:id])
      @shop = current_car_owner.shop
      @services = @shop&.services&.order(:name) || []
      @bookings = @vehicle.booking_requests.order(preferred_date: :desc).limit(5)
      @service_records = @vehicle.service_records.order(service_date: :desc).limit(5)
      @service_jobs = @vehicle.service_jobs.where(status: "completed").order(completed_at: :desc).limit(5)
    end

    def edit
      @vehicle = current_car_owner.vehicles.find(params[:id])
    end

    def update
      @vehicle = current_car_owner.vehicles.find(params[:id])
      if @vehicle.update(vehicle_params)
        redirect_to vehicle_path(@vehicle), notice: "Vehicle updated."
      else
        render :edit, status: :unprocessable_entity
      end
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
        destination = current_car_owner.vehicles.count == 1 ? onboarding_processing_path : vehicles_path
        redirect_to destination, notice: "Vehicle added to your garage."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def vehicle_params
      params.require(:car_us_vehicle).permit(
        :vin, :year, :make, :model, :trim, :engine_size, :transmission, :mileage, :photo
      )
    end
  end
end
