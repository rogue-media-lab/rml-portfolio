class ChangeServiceJobStatusDefault < ActiveRecord::Migration[8.0]
  def change
    change_column_default :car_us_service_jobs, :status, from: "completed", to: "open"
    # Existing completed jobs stay completed — only new jobs default to open
  end
end