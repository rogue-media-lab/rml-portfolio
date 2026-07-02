module CarUs
  class NotificationsController < CarUs::BaseController
    before_action :authenticate_car_owner!

    def index
      @notifications = current_car_owner.notifications.recent
    end
  end
end
