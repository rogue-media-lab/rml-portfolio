class AddShopNotifiedAtToBookingRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :car_us_booking_requests, :shop_notified_at, :datetime
  end
end
