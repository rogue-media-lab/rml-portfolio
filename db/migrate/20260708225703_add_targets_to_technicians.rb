class AddTargetsToTechnicians < ActiveRecord::Migration[8.0]
  def change
    add_column :technicians, :preferred_hours, :decimal, precision: 5, scale: 2, default: 40.0
    add_column :technicians, :target_hours, :decimal, precision: 5, scale: 2
    add_column :technicians, :target_service_ids, :jsonb, default: []
  end
end