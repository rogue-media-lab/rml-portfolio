module CarUs
  module Manager
    class FlashAlertsController < BaseController
      before_action :set_flash_alert, only: [ :show, :edit, :update, :destroy ]

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
          redirect_to manager_root_path
        else
          render :new, status: :unprocessable_entity
        end
      end

      def show
      end

      def edit
      end

      def update
        if @flash_alert.update(flash_alert_params)
          redirect_to manager_flash_alert_path(@flash_alert), notice: "Flash Sale updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @flash_alert.destroy
        redirect_to manager_flash_alerts_path, notice: "Flash Sale removed."
      end

      private

      def set_flash_alert
        @flash_alert = current_shop.flash_alerts.find(params[:id])
      end

      def flash_alert_params
        params.require(:car_us_flash_alert).permit(:title, :description, :discount_percentage, :duration_hours, :active)
      end
    end
  end
end