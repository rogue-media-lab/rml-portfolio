class CreateCarUsConcerns < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_concerns do |t|
      t.references :vehicle, null: false, foreign_key: { to_table: :car_us_vehicles }
      t.string :title
      t.text :description
      t.string :severity
      t.string :flagged_by

      t.timestamps
    end
  end
end
