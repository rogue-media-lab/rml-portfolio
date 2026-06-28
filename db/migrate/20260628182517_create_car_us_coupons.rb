class CreateCarUsCoupons < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_coupons do |t|
      t.references :shop, null: true, foreign_key: { to_table: :car_us_shops }
      t.string :code
      t.string :barcode
      t.text :description
      t.datetime :expires_at

      t.timestamps
    end
  end
end
