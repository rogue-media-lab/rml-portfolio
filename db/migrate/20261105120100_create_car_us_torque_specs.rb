class CreateCarUsTorqueSpecs < ActiveRecord::Migration[8.0]
  # Torque is keyed to the COMPONENT, not the vehicle. Alternator mounting bolts are
  # largely the same value across a platform, so one row per fastener covers many cars.
  # That is what makes this catalog cheap to curate and reusable across every vehicle.
  def change
    create_table :car_us_torque_specs do |t|
      t.string  :component, null: false          # "alternator", "brake caliper bracket", "lug nut"
      t.string  :fastener,  null: false          # "mounting bolt", "bracket to knuckle"
      t.decimal :value,     null: false, precision: 8, scale: 2
      t.string  :unit,      null: false, default: "ft-lb"
      t.string  :applies_to                      # optional vehicle/platform scope
      t.string  :source
      t.string  :confidence, default: "single_source"
      t.boolean :verified_on_vehicle, null: false, default: false
      t.text    :notes

      t.timestamps
    end

    add_index :car_us_torque_specs, :component
    add_index :car_us_torque_specs, %i[component fastener], unique: true,
              name: "index_car_us_torque_specs_on_component_and_fastener"
  end
end
