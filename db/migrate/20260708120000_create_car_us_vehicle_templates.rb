class CreateCarUsVehicleTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_vehicle_templates do |t|
      t.string :make, null: false
      t.string :model, null: false
      t.integer :year, null: false
      t.string :engine_size
      t.string :trim

      # Fluid specs — what the car requires
      t.string :oil_weight
      t.decimal :oil_capacity_qts, precision: 4, scale: 1
      t.string :coolant_type
      t.string :transmission_fluid_spec
      t.string :brake_fluid_spec

      # Part numbers — OEM equivalents
      t.string :oil_filter_oem
      t.string :cabin_air_filter_oem
      t.string :engine_air_filter_oem

      # Torque, plugs, tires
      t.integer :drain_plug_torque_ft_lbs
      t.string :spark_plug_spec
      t.string :tire_size
      t.integer :tire_pressure_f
      t.integer :tire_pressure_r

      # AI-generated content
      t.text :ai_difficulty_notes
      t.jsonb :ai_suggestions

      # Provenance
      t.string :source, default: "ai_generated", null: false
      t.references :verified_by_shop, foreign_key: { to_table: :car_us_shops }

      t.timestamps
    end

    add_index :car_us_vehicle_templates,
              [ :make, :model, :year, :engine_size ],
              unique: true,
              name: "idx_vehicle_templates_on_make_model_year_engine"
  end
end
