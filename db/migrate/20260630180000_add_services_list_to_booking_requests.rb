class AddServicesListToBookingRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :car_us_booking_requests, :service_types, :text
  end
end
