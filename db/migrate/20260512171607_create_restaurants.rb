class CreateRestaurants < ActiveRecord::Migration[8.0]
  def change
    create_table :restaurants do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :tagline
      t.string :address
      t.string :phone
      t.string :email
      t.string :place_id
      t.decimal :rating, precision: 2, scale: 1
      t.integer :review_count, default: 0
      t.string :price_level
      t.string :service_type

      # Theme
      t.string :primary_color, default: "#FDD835"
      t.string :accent_color, default: "#A10035"
      t.string :dark_color, default: "#1A237E"
      t.string :font_display, default: "Lilita One"
      t.string :font_body, default: "Nunito"

      # Images
      t.string :hero_image
      t.string :logo_image

      t.timestamps
    end

    add_index :restaurants, :slug, unique: true
  end
end
