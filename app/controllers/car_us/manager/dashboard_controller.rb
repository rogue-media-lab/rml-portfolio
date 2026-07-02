module CarUs
  module Manager
    class DashboardController < BaseController
      def index
        @total_customers = current_shop.car_owners.count
        @active_flash_alerts = current_shop.flash_alerts.active_alerts.count
        @total_redemptions = current_shop.redemptions.completed.count
        @recent_flash_alerts = current_shop.flash_alerts.order(created_at: :desc).limit(5)
        @technicians = current_shop.technicians.order(:email)

        @upcoming_bookings = CarUs::BookingRequest
          .joins(vehicle: :car_owner)
          .where(car_owners: { shop_id: current_shop.id })
          .where("preferred_date >= ?", Date.today)
          .order(preferred_date: :asc)
          .includes(:technician, vehicle: :car_owner)

        # Count unseen bookings before marking them
        @unnotified_count = @upcoming_bookings.where(shop_notified_at: nil).count

        # Mark all as seen by this shop
        CarUs::BookingRequest
          .joins(vehicle: :car_owner)
          .where(car_owners: { shop_id: current_shop.id })
          .where(shop_notified_at: nil)
          .update_all(shop_notified_at: Time.current)
      end
    end
  end
end
