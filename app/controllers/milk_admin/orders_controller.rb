# Orders Controller for Milk Admin
class MilkAdmin::OrdersController < ApplicationController
  before_action :authenticate_milk_admin!
  before_action :set_restaurant
  before_action :set_order, only: [:show, :update, :destroy]

  def index
    @orders = @restaurant.orders.order(created_at: :desc)
    @pending_count = @orders.pending.count
  end

  def show
    @order_items = @order.order_items.includes(:menu_item)
  end

  def update
    if @order.update(order_params)
      redirect_to milk_admin_restaurant_order_path(@restaurant, @order), notice: "Order updated."
    else
      redirect_to milk_admin_restaurant_orders_path(@restaurant), alert: "Could not update order."
    end
  end

  def destroy
    @order.destroy
    redirect_to milk_admin_restaurant_orders_path(@restaurant), notice: "Order deleted."
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find_by!(slug: params[:restaurant_id])
  end

  def set_order
    @order = @restaurant.orders.find(params[:id])
  end

  def order_params
    params.require(:order).permit(:status)
  end
end
