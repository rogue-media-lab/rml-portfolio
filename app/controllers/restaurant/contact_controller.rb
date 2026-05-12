module Restaurant
  class ContactController < ApplicationController
    include RestaurantScoped

    def index
      @contact = Contact.new
      @hours = @restaurant.hours.ordered
    end
  end
end
