class AddAiPersonalityToCarUsVehicles < ActiveRecord::Migration[8.0]
  def change
    add_column :car_us_vehicles, :ai_personality, :jsonb, default: {}
  end
end
