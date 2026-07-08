class AddAutoUpdatePartsToCarUsShops < ActiveRecord::Migration[8.0]
  def change
    add_column :car_us_shops, :auto_update_parts, :boolean, default: false, null: false
  end
end