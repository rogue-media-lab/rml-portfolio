module CarUs
  module Manager
    class TechniciansController < BaseController
      def index
        @technicians = current_shop.technicians.order(:email)
      end

      def new
        @technician = current_shop.technicians.build
      end

      def create
        @technician = current_shop.technicians.build(technician_params)
        if @technician.save
          redirect_to manager_technicians_path, notice: "Technician added."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @technician = current_shop.technicians.find(params[:id])
        @shop_services = current_shop.services.active.order(:name)
      end

      def update
        @technician = current_shop.technicians.find(params[:id])
        if @technician.update(technician_update_params)
          redirect_to manager_technicians_path, notice: "#{@technician.email} targets updated."
        else
          @shop_services = current_shop.services.active.order(:name)
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        tech = current_shop.technicians.find(params[:id])
        if tech == current_technician
          redirect_to manager_technicians_path, alert: "Cannot remove yourself."
        else
          tech.destroy
          redirect_to manager_technicians_path, notice: "Technician removed."
        end
      end

      private

      def technician_params
        params.require(:technician).permit(:email, :password, :password_confirmation)
      end

      def technician_update_params
        params.require(:technician).permit(
          :email, :password, :password_confirmation,
          :preferred_hours, :target_hours,
          target_service_ids: []
        )
      end
    end
  end
end
