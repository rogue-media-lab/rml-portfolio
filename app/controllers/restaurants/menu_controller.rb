module Restaurants
  class MenuController < ApplicationController
    include RestaurantScoped
    layout "restaurant"

    def index
      @categories = @restaurant.menu_categories.active.sorted.includes(:menu_items)
    end
  end
end
