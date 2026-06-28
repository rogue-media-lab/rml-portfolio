module CarUs
  module Manager
    class FlashAlertsController < BaseController
      def index
        @flash_alerts = current_shop.flash_alerts.order(created_at: :desc)
      end

      def new
        @flash_alert = current_shop.flash_alerts.build
      end

      def create
        @flash_alert = current_shop.flash_alerts.build(flash_alert_params)
        @flash_alert.technician = current_technician

        if @flash_alert.save
          flash[:notice] = "Flash Sale sent to #{current_shop.car_owners.count} customers!"
          redirect_to carus_manager_root_path
        else
          render :new, status: :unprocessable_entity
        end
      end

      def show
        @flash_alert = current_shop.flash_alerts.find(params[:id])
      end

      private

      def flash_alert_params
        params.require(:car_us_flash_alert).permit(:title, :description, :discount_percentage, :duration_hours)
      end
    end
  end
end
