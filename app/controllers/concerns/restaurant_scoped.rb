module RestaurantScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_restaurant
    helper_method :current_restaurant, :cart_item_count
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find_by!(slug: params[:restaurant_slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, notice: "Welcome, site ready."
  end

  def current_restaurant
    @restaurant
  end

  def cart_item_count
    (session[:cart] || {}).values.sum
  end
end
