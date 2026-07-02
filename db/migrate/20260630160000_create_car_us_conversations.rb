class CreateCarUsConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_conversations do |t|
      t.references :technician, null: false, foreign_key: { to_table: :technicians }
      t.references :vehicle, foreign_key: { to_table: :car_us_vehicles }
      t.string :title
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
