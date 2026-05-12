module Restaurants
  class PagesController < ApplicationController
    include RestaurantScoped
    layout "restaurant"

    def home
      @featured_items = @restaurant.menu_items.featured.active.includes(:menu_category).limit(6)
      @categories = @restaurant.menu_categories.active.sorted
      @testimonials = @restaurant.testimonials.active.featured.limit(3)
      @hours = @restaurant.hours.ordered

      # Look for restaurant-specific view first, fall back to default
      restaurant_view = "restaurants/#{@restaurant.slug.underscore}/pages/home"
      if lookup_context.exists?(restaurant_view, [], true)
        render restaurant_view
      end
    end

    def about
      @hours = @restaurant.hours.ordered

      restaurant_view = "restaurants/#{@restaurant.slug.underscore}/pages/about"
      if lookup_context.exists?(restaurant_view, [], true)
        render restaurant_view
      end
    end
  end
end
