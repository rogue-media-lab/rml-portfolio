class AddProfileFieldsToCarOwners < ActiveRecord::Migration[8.0]
  def change
    add_column :car_owners, :first_name, :string
    add_column :car_owners, :last_name, :string
    add_column :car_owners, :address, :string
  end
end
