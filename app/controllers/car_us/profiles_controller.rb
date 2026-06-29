module CarUs
  class ProfilesController < CarUs::BaseController
    before_action :authenticate_car_owner!

    def show
      @car_owner = current_car_owner
    end
  end
end
