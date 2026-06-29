class CreateCarUsServiceRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_service_records do |t|
      t.references :vehicle, null: false, foreign_key: { to_table: :car_us_vehicles }
      t.date :service_date
      t.integer :mileage
      t.text :description
      t.string :technician_name
      t.decimal :cost

      t.timestamps
    end
  end
end
