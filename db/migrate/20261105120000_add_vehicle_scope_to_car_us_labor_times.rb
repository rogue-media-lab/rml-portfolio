class AddVehicleScopeToCarUsLaborTimes < ActiveRecord::Migration[8.0]
  # Labor times were a flat list: one row per service, unique on service alone.
  # That cannot express "alternator is 1.2h generally, but 1.5h on a 2014 Avenger".
  # Add the vehicle scope and widen the uniqueness to match, so a generic row and
  # any number of vehicle-specific overrides can coexist.
  def up
    add_column :car_us_labor_times, :make, :string
    add_column :car_us_labor_times, :model, :string
    add_column :car_us_labor_times, :year_start, :integer
    add_column :car_us_labor_times, :year_end, :integer
    add_column :car_us_labor_times, :engine_size, :string
    add_column :car_us_labor_times, :generation, :string

    remove_index :car_us_labor_times, name: "index_car_us_labor_times_on_service"
    add_index :car_us_labor_times,
              %i[service make model year_start year_end],
              unique: true,
              name: "index_car_us_labor_times_on_service_and_vehicle"
    add_index :car_us_labor_times, %i[make model], name: "index_car_us_labor_times_on_make_and_model"
  end

  def down
    remove_index :car_us_labor_times, name: "index_car_us_labor_times_on_make_and_model"
    remove_index :car_us_labor_times, name: "index_car_us_labor_times_on_service_and_vehicle"
    add_index :car_us_labor_times, :service, unique: true, name: "index_car_us_labor_times_on_service"

    remove_column :car_us_labor_times, :generation
    remove_column :car_us_labor_times, :engine_size
    remove_column :car_us_labor_times, :year_end
    remove_column :car_us_labor_times, :year_start
    remove_column :car_us_labor_times, :model
    remove_column :car_us_labor_times, :make
  end
end
