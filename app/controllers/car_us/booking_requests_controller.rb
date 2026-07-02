module CarUs
  class BookingRequestsController < CarUs::BaseController
    before_action :authenticate_car_owner!
    before_action :set_vehicle

    def new
      @booking = @vehicle.booking_requests.build
      @shop = current_car_owner.shop
      @services = @shop&.services&.order(:name) || []

      # Default to tomorrow for availability lookup
      date = params[:preferred_date].present? ? Date.parse(params[:preferred_date]) : Date.tomorrow
      max = @shop&.max_bookings_per_slot || 3

      # All 4 time slots with current booking counts
      time_slots = [ "8:00 AM", "10:00 AM", "1:00 PM", "3:00 PM" ]
      existing = CarUs::BookingRequest
        .where(preferred_date: date)
        .group(:preferred_time)
        .count

      @available_slots = time_slots.map do |time|
        count = existing[time] || 0
        {
          time: time,
          count: count,
          max: max,
          available: count < max,
          label: if count >= max
                   "#{time} — Full"
                 elsif count >= max - 1
                   "#{time} — 1 spot left"
                 else
                   time
                 end
        }
      end
    end

    def confirm
      @booking = @vehicle.booking_requests.build
      @shop = current_car_owner.shop
      @services = @shop&.services&.order(:name) || []
      @selected = Array(params[:service_types])
      @selected_services = @services.select { |s| @selected.include?(s.name) }
      @service_total = @selected_services.sum { |s| s.price || 0 }
      @flash_alerts = @shop&.flash_alerts&.active_alerts || []
      @applied_alert = params[:flash_alert_id].present? ? @flash_alerts.find_by(id: params[:flash_alert_id]) : nil
      @discount = @applied_alert ? (@service_total * @applied_alert.discount_percentage / 100.0).round : 0

      @pricing = CarUs::PricingService.new(shop: @shop, service_total: @service_total)
      @breakdown = @pricing.breakdown
    end

    def create
      @booking = @vehicle.booking_requests.build(booking_params)
      @booking.status = "confirmed"

      if @booking.save
        redirect_to thank_you_vehicle_booking_requests_path(@vehicle, booking_id: @booking.id)
      else
        @shop = current_car_owner.shop
        @services = @shop&.services&.order(:name) || []
        @selected = Array(@booking.service_types&.split(",")&.map(&:strip))
        @selected_services = @services.select { |s| @selected.include?(s.name) }
        @service_total = @selected_services.sum { |s| s.price || 0 }
        @pricing = CarUs::PricingService.new(shop: @shop, service_total: @service_total)
        @breakdown = @pricing.breakdown
        render :confirm, status: :unprocessable_entity
      end
    end

    def thank_you
      @booking = @vehicle.booking_requests.find(params[:booking_id])
      @shop = current_car_owner.shop
      @selected = Array(@booking.service_types&.split(",")&.map(&:strip))
      @services = @shop&.services&.order(:name) || []
      @selected_services = @services.select { |s| @selected.include?(s.name) }
      @service_total = @selected_services.sum { |s| s.price || 0 }
      if @booking.flash_alert
        @discount = (@service_total * @booking.flash_alert.discount_percentage / 100.0).round
      else
        @discount = 0
      end
      @pricing = CarUs::PricingService.new(shop: @shop, service_total: @service_total)
      @breakdown = @pricing.breakdown
    end

    private

    def set_vehicle
      @vehicle = current_car_owner.vehicles.find(params[:vehicle_id])
    end

    def booking_params
      params.require(:car_us_booking_request).permit(:service_types, :preferred_date, :preferred_time, :notes, :flash_alert_id)
    end
  end
end
