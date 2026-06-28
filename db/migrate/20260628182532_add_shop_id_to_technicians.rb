class AddShopIdToTechnicians < ActiveRecord::Migration[8.0]
  def change
    add_reference :technicians, :shop, null: false, foreign_key: { to_table: :car_us_shops }
  end
end