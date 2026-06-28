class AddShopIdToCarOwners < ActiveRecord::Migration[8.0]
  def change
    add_reference :car_owners, :shop, null: true, foreign_key: { to_table: :car_us_shops }
  end
end