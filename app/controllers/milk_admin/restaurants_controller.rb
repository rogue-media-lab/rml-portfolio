# Restaurants Controller for Milk Admin
class MilkAdmin::RestaurantsController < ApplicationController
  before_action :authenticate_milk_admin!
  before_action :set_restaurant, only: [:show, :edit, :update, :destroy]

  def index
    @restaurants = Restaurant.order(:name)
  end

  def show
    @menu_categories = @restaurant.menu_categories.sorted
    @menu_items = @restaurant.menu_items.includes(:menu_category)
    @testimonials = @restaurant.testimonials
    @hours = @restaurant.hours.ordered
    @recent_orders = @restaurant.orders.order(created_at: :desc).limit(10)
  end

  def new
    @restaurant = Restaurant.new
  end

  def create
    @restaurant = Restaurant.new(restaurant_params)
    if @restaurant.save
      redirect_to milk_admin_restaurant_path(@restaurant), notice: "Restaurant created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @restaurant.update(restaurant_params)
      redirect_to milk_admin_restaurant_path(@restaurant), notice: "Restaurant updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @restaurant.destroy
    redirect_to milk_admin_restaurants_path, notice: "Restaurant deleted."
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find_by!(slug: params[:id])
  end

  def restaurant_params
    params.require(:restaurant).permit(
      :name, :slug, :tagline, :address, :phone, :email,
      :place_id, :rating, :review_count, :price_level, :service_type,
      :primary_color, :accent_color, :dark_color,
      :font_display, :font_body, :hero_image, :logo_image
    )
  end
end
