module CarUs
  class ShopsController < BaseController
    def show
      @shop = CarUs::Shop.find_by!(slug: params[:slug])
      @services = @shop.services.where(active: true).order(:name)
      @active_deals = @shop.flash_alerts.active_alerts.order(created_at: :desc).limit(5)
    end
  end
end