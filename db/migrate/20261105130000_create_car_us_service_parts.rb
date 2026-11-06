class CreateCarUsServiceParts < ActiveRecord::Migration[8.0]
  # Repair parts, not consumables. CarUs::ShopPart covers what a shop stocks and prefers
  # (filters, fluids, wiper blades) via a closed CATEGORIES list, and CarUs::VehicleTemplate
  # holds OEM numbers for consumables only. Neither can express "the alternator for a
  # 2021 Ford Escape" - there is nowhere to put it and the category list rejects it.
  #
  # This mirrors car_us_labor_times deliberately: a generic row for a service plus optional
  # vehicle-specific overrides, so it stays consistent with how labor already resolves.
  def change
    create_table :car_us_service_parts do |t|
      t.string  :service, null: false              # matches the labor_times service vocabulary
      t.string  :part_name, null: false
      t.string  :part_number
      t.string  :oem_number
      t.string  :brand
      t.string  :position                          # "LH" / "RH" / "set" / "per axle"
      t.decimal :quantity, precision: 6, scale: 2, default: "1.0"
      t.decimal :unit_cost, precision: 8, scale: 2
      t.string  :supplier
      t.string  :source
      t.string  :confidence, default: "single_source"
      t.boolean :verified_on_vehicle, null: false, default: false
      t.text    :notes

      t.string  :make
      t.string  :model
      t.integer :year_start
      t.integer :year_end

      t.timestamps
    end

    add_index :car_us_service_parts, :service
    add_index :car_us_service_parts, %i[make model]
    add_index :car_us_service_parts,
              %i[service part_name make model year_start year_end],
              unique: true,
              name: "index_car_us_service_parts_on_service_and_vehicle"
  end
end
