module CarUs
  class ConcernsController < CarUs::BaseController
    before_action :authenticate_car_owner!
    before_action :set_vehicle

    def new
      @concern = @vehicle.concerns.build
    end

    def create
      @concern = @vehicle.concerns.build(concern_params)

      if @concern.save
        redirect_to vehicle_path(@vehicle), notice: "Concern flagged."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def set_vehicle
      @vehicle = current_car_owner.vehicles.find(params[:vehicle_id])
    end

    def concern_params
      params.require(:car_us_concern).permit(:title, :description, :severity, :flagged_by)
    end
  end
end