class CreateCarUsFlashAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_flash_alerts do |t|
      t.references :shop, null: false, foreign_key: { to_table: :car_us_shops }
      t.references :technician, null: false, foreign_key: { to_table: :technicians }
      t.string :title
      t.text :description
      t.integer :discount_percentage
      t.integer :duration_hours
      t.string :code
      t.datetime :expires_at
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
