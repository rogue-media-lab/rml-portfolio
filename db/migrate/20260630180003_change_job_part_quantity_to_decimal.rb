class ChangeJobPartQuantityToDecimal < ActiveRecord::Migration[8.0]
  def change
    change_column :car_us_job_parts, :quantity, :decimal, precision: 6, scale: 2, default: 1
  end
end
