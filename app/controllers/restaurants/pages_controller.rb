module Restaurants
  class PagesController < ApplicationController
    include RestaurantScoped
    layout "restaurant"

    def home
      @featured_items = @restaurant.menu_items.featured.active.includes(:menu_category).limit(6)
      @categories = @restaurant.menu_categories.active.sorted
      @testimonials = @restaurant.testimonials.active.featured.limit(3)
      @hours = @restaurant.hours.ordered
    end

    def about
      @hours = @restaurant.hours.ordered
    end
  end
end
