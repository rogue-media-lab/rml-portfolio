module Restaurants
  class ContactController < ApplicationController
    include RestaurantScoped
    layout "restaurant"

    def index
      @contact = Contact.new
      @hours = @restaurant.hours.ordered
    end
  end
end
