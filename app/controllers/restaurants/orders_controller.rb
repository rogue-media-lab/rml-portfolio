module Restaurants
  class OrdersController < ApplicationController
    include RestaurantScoped
    layout "restaurant"

    def new
      @cart = session[:cart] || {}
      @cart_items = build_cart_items
      @order = Order.new
    end

    def create
      @order = @restaurant.orders.build(order_params)
      @cart = session[:cart] || {}
      @cart_items = build_cart_items

      @order.total = @cart_items.sum { |ci| ci[:subtotal] }

      if @order.save
        @cart_items.each do |ci|
          @order.order_items.create!(
            menu_item: ci[:item],
            quantity: ci[:quantity],
            price: ci[:item].price
          )
        end
        session[:cart] = {}
        redirect_to restaurant_order_confirmation_path(@restaurant.slug, @order)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def confirmation
      @order = @restaurant.orders.find(params[:id])
    end

    private

    def order_params
      params.require(:order).permit(:customer_name, :phone, :pickup_time)
    end

    def build_cart_items
      return [] if session[:cart].blank?
      item_ids = session[:cart].keys
      items = MenuItem.where(id: item_ids).index_by(&:id)
      session[:cart].map do |item_id, quantity|
        item = items[item_id.to_i]
        next unless item
        { item: item, quantity: quantity, subtotal: item.price * quantity }
      end.compact
    end
  end
end
