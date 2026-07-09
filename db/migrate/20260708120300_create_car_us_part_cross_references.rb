class CreateCarUsPartCrossReferences < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_part_cross_references do |t|
      t.string :oem_number, null: false
      t.string :brand, null: false
      t.string :brand_number, null: false
      t.string :part_category

      t.timestamps
    end

    add_index :car_us_part_cross_references,
              [ :oem_number, :brand ],
              unique: true,
              name: "idx_cross_refs_on_oem_and_brand"
  end
end
