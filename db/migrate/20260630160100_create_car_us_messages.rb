class CreateCarUsMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :car_us_messages do |t|
      t.references :conversation, null: false, foreign_key: { to_table: :car_us_conversations }
      t.string :role, null: false, default: "tech"  # tech | assistant
      t.text :content
      t.jsonb :metadata  # stores specs, suggestions, etc.

      t.timestamps
    end
  end
end
