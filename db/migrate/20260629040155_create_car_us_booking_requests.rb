class CreateCarUsBookingRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_booking_requests do |t|
      t.references :vehicle, null: false, foreign_key: { to_table: :car_us_vehicles }
      t.string :service_type
      t.date :preferred_date
      t.string :preferred_time
      t.text :notes
      t.string :status

      t.timestamps
    end
  end
end
