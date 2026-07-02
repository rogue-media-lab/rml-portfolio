module CarUs
  module Manager
    class BookingsController < BaseController
      before_action :set_booking, only: [ :edit, :update ]

      def edit
        @technicians = current_shop.technicians.order(:email)
      end

      def update
        if @booking.update(booking_params)
          redirect_to manager_root_path, notice: "Booking updated."
        else
          @technicians = current_shop.technicians.order(:email)
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_booking
        @booking = CarUs::BookingRequest
          .joins(vehicle: :car_owner)
          .where(car_owners: { shop_id: current_shop.id })
          .find(params[:id])
      end

      def booking_params
        params.require(:car_us_booking_request).permit(
          :service_types, :preferred_date, :preferred_time, :notes,
          :technician_id, :flash_alert_id
        )
      end
    end
  end
end
