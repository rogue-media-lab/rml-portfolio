class AddOwnerProfileToCarOwners < ActiveRecord::Migration[8.0]
  def change
    add_column :car_owners, :work_address, :string
    add_column :car_owners, :occupation, :string
    add_column :car_owners, :work_days, :string
    add_column :car_owners, :commute_type, :string
    add_column :car_owners, :onboarding_step, :string
    add_column :car_owners, :onboarding_completed, :boolean
  end
end
