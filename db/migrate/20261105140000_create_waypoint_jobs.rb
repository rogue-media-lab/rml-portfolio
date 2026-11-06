class CreateWaypointJobs < ActiveRecord::Migration[8.0]
  # A quote, and then a job.
  #
  # Deliberately standalone: car_us_service_jobs requires a technician_id and a
  # vehicle_id (both NOT NULL), and a quote happens before there is either. The
  # capture surface must be able to record a price with no shop, no tech and no
  # vehicle row - so it gets its own table rather than a pile of nullable FKs.
  #
  # parts / torque / gaps are JSON SNAPSHOTS, not references. An estimate is a record
  # of a price that was offered to someone; it must freeze at quote time and must not
  # silently reprice itself when the parts catalog or the labor rate changes later.
  def change
    create_table :waypoint_jobs do |t|
      t.string  :door, default: "app"            # app | sms | voice | discord
      t.text    :raw_capture                     # exactly what was said, verbatim

      t.integer :vehicle_year
      t.string  :vehicle_make
      t.string  :vehicle_model
      t.integer :mileage

      t.string  :service, null: false
      t.decimal :labor_hours, precision: 6, scale: 2
      t.decimal :labor_rate,  precision: 8, scale: 2
      t.decimal :labor_total, precision: 10, scale: 2
      t.decimal :parts_total, precision: 10, scale: 2
      t.decimal :total,       precision: 10, scale: 2

      t.jsonb   :parts, default: []              # snapshot at quote time
      t.jsonb   :torque, default: []
      t.jsonb   :gaps, default: []

      t.string  :status, null: false, default: "quoted"   # quoted | done | paid
      t.datetime :quoted_at
      t.datetime :completed_at
      t.datetime :paid_on
      t.text :notes

      t.timestamps
    end

    add_index :waypoint_jobs, :status
    add_index :waypoint_jobs, :created_at
    add_index :waypoint_jobs, %i[vehicle_make vehicle_model]
  end
end
