class CreateCarUsVehicles < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_vehicles do |t|
      t.references :car_owner, null: false, foreign_key: true
      t.string :vin
      t.integer :year
      t.string :make
      t.string :model
      t.string :trim
      t.string :engine_size
      t.string :transmission
      t.integer :mileage

      t.timestamps
    end
    add_index :car_us_vehicles, :vin, unique: true
  end
end
