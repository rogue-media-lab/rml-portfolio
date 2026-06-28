module CarUs
  module Manager
    class DashboardController < BaseController
      def index
        @total_customers = current_shop.car_owners.count
        @active_flash_alerts = current_shop.flash_alerts.active_alerts.count
        @total_redemptions = current_shop.redemptions.completed.count
        @recent_flash_alerts = current_shop.flash_alerts.order(created_at: :desc).limit(5)
      end
    end
  end
end
