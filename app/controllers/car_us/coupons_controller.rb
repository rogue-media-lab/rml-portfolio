module CarUs
  class CouponsController < BaseController
    before_action :authenticate_car_owner!

    def index
      return redirect_to new_car_owner_session_path unless current_car_owner.shop
      @active_coupons = current_car_owner.shop.flash_alerts.active_alerts.order(created_at: :desc)
      @expired_coupons = current_car_owner.shop.flash_alerts
                          .where("expires_at < ?", Time.current)
                          .order(created_at: :desc).limit(5)
    end

    def show
      @coupon = CarUs::FlashAlert.find(params[:id])
    end
  end
end