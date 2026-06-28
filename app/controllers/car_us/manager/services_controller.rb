module CarUs
  module Manager
    class ServicesController < BaseController
      before_action :set_service, only: [ :edit, :update, :destroy ]

      def index
        @services = current_shop.services.order(:name)
      end

      def new
        @service = current_shop.services.build
      end

      def create
        @service = current_shop.services.build(service_params)
        if @service.save
          redirect_to manager_services_path, notice: "Service added."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @service.update(service_params)
          redirect_to manager_services_path, notice: "Service updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @service.destroy
        redirect_to manager_services_path, notice: "Service removed."
      end

      private

      def set_service
        @service = current_shop.services.find(params[:id])
      end

      def service_params
        params.require(:car_us_service).permit(:name, :description, :price, :duration_minutes, :active)
      end
    end
  end
end