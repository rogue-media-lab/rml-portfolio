module CarUs
  module Manager
    class BaseController < ApplicationController
      before_action :authenticate_technician!
      layout "car_us/technician"

      private

      def current_shop
        @current_shop ||= current_technician.shop
      end
      helper_method :current_shop
    end
  end
end
