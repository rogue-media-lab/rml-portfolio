namespace :carus do
  desc "Backfill VehicleTemplates from existing vehicles with ai_specs"
  task backfill_templates: :environment do
    vehicles = CarUs::Vehicle.where.not(ai_specs: [nil, ""])
    created = 0
    skipped = 0

    vehicles.find_each do |v|
      specs = v.ai_specs.is_a?(String) ? JSON.parse(v.ai_specs) : v.ai_specs
      next if specs.blank?

      template = CarUs::VehicleTemplate.find_or_initialize_by(
        make: v.make,
        model: v.model,
        year: v.year,
        engine_size: v.engine_size
      )

      if template.persisted?
        skipped += 1
        next
      end

      template.assign_attributes(
        trim: v.trim,
        oil_weight: specs["oil_weight"],
        oil_capacity_qts: specs["oil_capacity_qts"],
        oil_filter_oem: specs["oil_filter"],
        cabin_air_filter_oem: specs["cabin_air_filter"],
        engine_air_filter_oem: specs["engine_air_filter"],
        coolant_type: specs["coolant_type"],
        transmission_fluid_spec: specs["transmission_fluid"],
        brake_fluid_spec: specs["brake_fluid"],
        drain_plug_torque_ft_lbs: specs["drain_plug_torque_ft_lbs"],
        spark_plug_spec: specs["spark_plug"],
        tire_size: specs["tire_size"],
        tire_pressure_f: specs["tire_pressure_f"],
        tire_pressure_r: specs["tire_pressure_r"],
        ai_difficulty_notes: v.ai_difficulty_notes,
        ai_suggestions: v.ai_suggestions,
        source: "ai_generated"
      )

      template.save!
      created += 1
    end

    puts "Backfill complete: #{created} templates created, #{skipped} already existed."
    puts "Total VehicleTemplates: #{CarUs::VehicleTemplate.count}"
  end
end