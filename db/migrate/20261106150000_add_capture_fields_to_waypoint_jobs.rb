class AddCaptureFieldsToWaypointJobs < ActiveRecord::Migration[8.0]
  # The fields that make a job findable later. A repair order that cannot answer "which
  # car was that, and who owns it" is a receipt, not a record.
  #
  # VIN is the one that matters most: it identifies a vehicle independently of how anyone
  # types the make or model, so it is the key that lets "what did I do on this car before"
  # work even when next time it is called a "Sierra" and not a "GMC Sierra 1500".
  def change
    add_column :waypoint_jobs, :vin, :string
    add_column :waypoint_jobs, :plate, :string
    add_column :waypoint_jobs, :plate_state, :string
    add_column :waypoint_jobs, :vehicle_color, :string
    add_column :waypoint_jobs, :vehicle_engine, :string

    add_column :waypoint_jobs, :customer_name, :string
    add_column :waypoint_jobs, :customer_phone, :string
    add_column :waypoint_jobs, :customer_address, :string

    # Reporting and lookup keys. A job list is scanned by car, by plate and by customer,
    # so those three are worth an index from the start.
    add_index :waypoint_jobs, :vin
    add_index :waypoint_jobs, :plate
    add_index :waypoint_jobs, :customer_name
  end
end
