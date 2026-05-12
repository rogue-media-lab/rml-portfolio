module RestaurantScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_restaurant
    helper_method :current_restaurant
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find_by!(slug: params[:restaurant_slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Restaurant not found"
  end

  def current_restaurant
    @restaurant
  end
end
