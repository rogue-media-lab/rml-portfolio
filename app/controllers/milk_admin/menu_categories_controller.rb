# Menu Categories Controller for Milk Admin
class MilkAdmin::MenuCategoriesController < ApplicationController
  before_action :authenticate_milk_admin!
  before_action :set_restaurant
  before_action :set_menu_category, only: [:edit, :update, :destroy]

  def index
    @menu_categories = @restaurant.menu_categories.sorted
  end

  def new
    @menu_category = @restaurant.menu_categories.build
  end

  def create
    @menu_category = @restaurant.menu_categories.build(menu_category_params)
    if @menu_category.save
      redirect_to milk_admin_restaurant_menu_categories_path(@restaurant), notice: "Category created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @menu_category.update(menu_category_params)
      redirect_to milk_admin_restaurant_menu_categories_path(@restaurant), notice: "Category updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @menu_category.destroy
    redirect_to milk_admin_restaurant_menu_categories_path(@restaurant), notice: "Category deleted."
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find_by!(slug: params[:restaurant_id])
  end

  def set_menu_category
    @menu_category = @restaurant.menu_categories.find(params[:id])
  end

  def menu_category_params
    params.require(:menu_category).permit(:name, :active, :sort_order)
  end
end
