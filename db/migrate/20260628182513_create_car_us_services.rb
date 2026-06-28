class CreateCarUsServices < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_services do |t|
      t.references :shop, null: false, foreign_key: { to_table: :car_us_shops }
      t.string :name
      t.text :description
      t.decimal :price
      t.integer :duration_minutes
      t.boolean :active, default: true

      t.timestamps
    end
  end
end