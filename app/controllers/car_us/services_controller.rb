module CarUs
  class ServicesController < BaseController
    before_action :authenticate_car_owner!

    def index
      @services = CarUs::Service.all.order(:name)
    end
  end
end
