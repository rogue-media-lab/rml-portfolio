module CarUs
  module Manager
    class BaseController < ApplicationController
      before_action :authenticate_technician!
      before_action :require_manager!
      layout "car_us/technician"

      private

      def require_manager!
        unless current_technician.manager?
          redirect_to tech_lookups_path, alert: "Access denied. Technicians use the tech tools."
        end
      end

      def current_shop
        @current_shop ||= current_technician.shop
      end
      helper_method :current_shop
    end
  end
end
