class CreateCarUsShopParts < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_shop_parts do |t|
      t.references :shop, null: false, foreign_key: { to_table: :car_us_shops }
      t.references :vehicle_template, foreign_key: { to_table: :car_us_vehicle_templates }
      t.string :part_category, null: false
      t.string :oem_number
      t.string :shop_number, null: false
      t.string :brand

      t.timestamps
    end

    add_index :car_us_shop_parts,
              [ :shop_id, :vehicle_template_id, :part_category ],
              unique: true,
              name: "idx_shop_parts_on_shop_template_category"
  end
end
