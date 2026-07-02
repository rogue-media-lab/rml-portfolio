class AddFlashAlertIdToBookingRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :car_us_booking_requests, :flash_alert_id, :integer
  end
end
