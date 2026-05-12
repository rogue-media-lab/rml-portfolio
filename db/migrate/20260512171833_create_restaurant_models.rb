class CreateRestaurantModels < ActiveRecord::Migration[8.0]
  def change
    create_table :menu_categories do |t|
      t.references :restaurant, foreign_key: true, null: false
      t.string :name, null: false
      t.boolean :active, default: true
      t.integer :sort_order, default: 0
      t.timestamps
    end

    create_table :menu_items do |t|
      t.references :menu_category, foreign_key: true, null: false
      t.references :restaurant, foreign_key: true, null: false
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 8, scale: 2, null: false
      t.boolean :active, default: true
      t.boolean :featured, default: false
      t.timestamps
    end

    create_table :testimonials do |t|
      t.references :restaurant, foreign_key: true, null: false
      t.string :customer_name, null: false
      t.text :quote, null: false
      t.integer :stars, default: 5
      t.boolean :active, default: true
      t.boolean :featured, default: false
      t.timestamps
    end

    create_table :hours do |t|
      t.references :restaurant, foreign_key: true, null: false
      t.integer :day_of_week, null: false
      t.time :open_time
      t.time :close_time
      t.boolean :closed, default: false
      t.timestamps
    end

    create_table :reservations do |t|
      t.references :restaurant, foreign_key: true, null: false
      t.string :customer_name, null: false
      t.string :phone, null: false
      t.integer :party_size, null: false
      t.date :reservation_date, null: false
      t.time :reservation_time, null: false
      t.text :special_requests
      t.string :status, default: "pending"
      t.timestamps
    end

    create_table :orders do |t|
      t.references :restaurant, foreign_key: true, null: false
      t.string :customer_name, null: false
      t.string :phone, null: false
      t.time :pickup_time
      t.decimal :total, precision: 8, scale: 2, null: false
      t.string :status, default: "pending"
      t.timestamps
    end

    create_table :order_items do |t|
      t.references :order, foreign_key: true, null: false
      t.references :menu_item, foreign_key: true, null: false
      t.integer :quantity, default: 1, null: false
      t.decimal :price, precision: 8, scale: 2, null: false
      t.timestamps
    end
  end
end
