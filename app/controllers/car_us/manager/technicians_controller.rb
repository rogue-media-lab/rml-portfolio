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
    end
  end
end
