module Restaurants
  class CartController < ApplicationController
    include RestaurantScoped
    layout "restaurant"

    def show
      @cart = session[:cart] || {}
      @cart_items = build_cart_items
    end

    def add
      item_id = params[:menu_item_id].to_s
      session[:cart] ||= {}
      session[:cart][item_id] = (session[:cart][item_id] || 0) + 1
      redirect_back fallback_location: restaurant_menu_path(@restaurant.slug)
    end

    def update
      item_id = params[:menu_item_id].to_s
      quantity = params[:quantity].to_i
      session[:cart] ||= {}
      if quantity <= 0
        session[:cart].delete(item_id)
      else
        session[:cart][item_id] = quantity
      end
      redirect_to restaurant_cart_path(@restaurant.slug)
    end

    def remove
      session[:cart]&.delete(params[:menu_item_id].to_s)
      redirect_to restaurant_cart_path(@restaurant.slug)
    end

    def clear
      session[:cart] = {}
      redirect_to restaurant_cart_path(@restaurant.slug)
    end

    private

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
