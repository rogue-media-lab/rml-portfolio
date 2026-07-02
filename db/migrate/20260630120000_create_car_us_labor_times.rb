class CreateCarUsLaborTimes < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_labor_times do |t|
      t.string :service, null: false
      t.string :category
      t.decimal :hours, null: false
      t.text :notes

      t.timestamps
    end
    add_index :car_us_labor_times, :service, unique: true
  end
end
