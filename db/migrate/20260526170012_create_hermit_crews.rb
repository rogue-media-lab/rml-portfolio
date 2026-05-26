class CreateHermitCrews < ActiveRecord::Migration[8.0]
  def change
    create_table :hermit_crews do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :image_url
      t.integer :season, null: false

      t.timestamps
    end

    add_index :hermit_crews, :slug, unique: true
  end
end
