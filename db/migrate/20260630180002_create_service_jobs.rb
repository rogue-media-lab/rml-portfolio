class CreateServiceJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_service_jobs do |t|
      t.references :vehicle, null: false, foreign_key: { to_table: :car_us_vehicles }
      t.references :technician, null: false, foreign_key: true
      t.string :description, null: false
      t.decimal :book_hours, precision: 4, scale: 2
      t.string :status, default: "completed", null: false
      t.text :notes
      t.datetime :completed_at

      t.timestamps
    end

    create_table :car_us_job_parts do |t|
      t.references :service_job, null: false, foreign_key: { to_table: :car_us_service_jobs }
      t.string :name, null: false
      t.integer :quantity, default: 1
      t.decimal :cost, precision: 8, scale: 2

      t.timestamps
    end
  end
end
