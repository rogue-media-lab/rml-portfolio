class AddAiColumnsToCarUsVehicles < ActiveRecord::Migration[8.0]
  def change
    add_column :car_us_vehicles, :ai_specs, :text
    add_column :car_us_vehicles, :ai_suggestions, :text
    add_column :car_us_vehicles, :ai_plain_english, :text
    add_column :car_us_vehicles, :ai_difficulty_notes, :text
    add_column :car_us_vehicles, :last_lookup_at, :datetime
    add_column :car_us_vehicles, :looked_up_by, :integer
  end
end
