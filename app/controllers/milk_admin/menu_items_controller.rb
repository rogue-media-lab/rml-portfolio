# Menu Items Controller for Milk Admin
class MilkAdmin::MenuItemsController < ApplicationController
  before_action :authenticate_milk_admin!
  before_action :set_restaurant
  before_action :set_menu_item, only: [:edit, :update, :destroy]

  def index
    @menu_items = @restaurant.menu_items.includes(:menu_category).order(:name)
    @menu_categories = @restaurant.menu_categories.sorted
  end

  def new
    @menu_item = @restaurant.menu_items.build
    @menu_categories = @restaurant.menu_categories.sorted
  end

  def create
    @menu_item = @restaurant.menu_items.build(menu_item_params)
    if @menu_item.save
      redirect_to milk_admin_restaurant_menu_items_path(@restaurant), notice: "Menu item created."
    else
      @menu_categories = @restaurant.menu_categories.sorted
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @menu_categories = @restaurant.menu_categories.sorted
  end

  def update
    if @menu_item.update(menu_item_params)
      redirect_to milk_admin_restaurant_menu_items_path(@restaurant), notice: "Menu item updated."
    else
      @menu_categories = @restaurant.menu_categories.sorted
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @menu_item.destroy
    redirect_to milk_admin_restaurant_menu_items_path(@restaurant), notice: "Menu item deleted."
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find_by!(slug: params[:restaurant_id])
  end

  def set_menu_item
    @menu_item = @restaurant.menu_items.find(params[:id])
  end

  def menu_item_params
    params.require(:menu_item).permit(:name, :description, :price, :menu_category_id, :active, :featured)
  end
end
