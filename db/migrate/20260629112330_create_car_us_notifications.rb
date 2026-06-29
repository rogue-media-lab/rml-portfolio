class CreateCarUsNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_notifications do |t|
      t.references :car_owner, null: false, foreign_key: true
      t.string :title
      t.text :body
      t.boolean :read
      t.string :category

      t.timestamps
    end
  end
end
