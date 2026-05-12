# Hours Controller for Milk Admin
class MilkAdmin::HoursController < ApplicationController
  before_action :authenticate_milk_admin!
  before_action :set_restaurant
  before_action :set_hour, only: [ :edit, :update ]

  def index
    @hours = @restaurant.hours.ordered
  end

  def edit
  end

  def update
    if @hour.update(hour_params)
      redirect_to milk_admin_restaurant_hours_path(@restaurant), notice: "Hours updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find_by!(slug: params[:restaurant_id])
  end

  def set_hour
    @hour = @restaurant.hours.find(params[:id])
  end

  def hour_params
    params.require(:hour).permit(:open_time, :close_time, :closed)
  end
end
