module Restaurant
  class MenuController < ApplicationController
    include RestaurantScoped

    def index
      @categories = @restaurant.menu_categories.active.sorted.includes(:menu_items)
    end
  end
end
