class CreateCarUsRedemptions < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_redemptions do |t|
      t.references :redeemable, polymorphic: true, null: false
      t.references :car_owner, null: false, foreign_key: { to_table: :car_owners }
      t.references :shop, null: false, foreign_key: { to_table: :car_us_shops }
      t.references :technician, null: true, foreign_key: { to_table: :technicians }
      t.datetime :redeemed_at

      t.timestamps
    end
  end
end
