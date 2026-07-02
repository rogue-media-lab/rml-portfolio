module CarUs
  class ProfilesController < CarUs::BaseController
    before_action :authenticate_car_owner!

    def show
      @car_owner = current_car_owner
    end

    def edit
      @car_owner = current_car_owner
    end

    def update
      if current_car_owner.update(car_owner_params)
        redirect_to profile_path, notice: "Profile updated."
      else
        @car_owner = current_car_owner
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def car_owner_params
      params.require(:car_owner).permit(:avatar, :first_name, :last_name, :address)
    end
  end
end
