module CarUs
  class BookingRequestsController < CarUs::BaseController
    before_action :authenticate_car_owner!
    before_action :set_vehicle

    def new
      @booking = @vehicle.booking_requests.build
    end

    def create
      @booking = @vehicle.booking_requests.build(booking_params)
      @booking.status = "pending"

      if @booking.save
        redirect_to vehicle_path(@vehicle), notice: "Appointment requested!"
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def set_vehicle
      @vehicle = current_car_owner.vehicles.find(params[:vehicle_id])
    end

    def booking_params
      params.require(:car_us_booking_request).permit(:service_type, :preferred_date, :preferred_time, :notes)
    end
  end
end