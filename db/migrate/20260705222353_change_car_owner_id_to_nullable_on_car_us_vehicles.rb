class ChangeCarOwnerIdToNullableOnCarUsVehicles < ActiveRecord::Migration[8.0]
  def change
    change_column_null :car_us_vehicles, :car_owner_id, true
  end
end