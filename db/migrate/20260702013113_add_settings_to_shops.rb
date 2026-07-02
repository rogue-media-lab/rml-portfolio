class AddSettingsToShops < ActiveRecord::Migration[8.0]
  def change
    add_column :car_us_shops, :settings, :jsonb, default: {}
  end
end
