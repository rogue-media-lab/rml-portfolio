class AddTechnicianToBookingRequests < ActiveRecord::Migration[8.0]
  def change
    add_reference :car_us_booking_requests, :technician, null: true, foreign_key: true
  end
end
