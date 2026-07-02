class AddRoleToTechnicians < ActiveRecord::Migration[8.0]
  def change
    add_column :technicians, :role, :string, default: "tech", null: false
    add_index :technicians, :role
  end
end
