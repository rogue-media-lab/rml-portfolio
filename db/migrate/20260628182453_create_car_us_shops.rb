class CreateCarUsShops < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_shops do |t|
      t.string :name
      t.string :slug
      t.string :address
      t.string :phone
      t.string :email
      t.string :website
      t.text :description
      t.boolean :active

      t.timestamps
    end
  end
end
