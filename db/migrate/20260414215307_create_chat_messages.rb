class CreateChatMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_messages do |t|
      t.references :chat_session, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.integer :input_tokens, default: 0
      t.integer :output_tokens, default: 0
      t.decimal :cost_usd, default: "0.0"
      t.string :media_type
      t.string :media_url

      t.timestamps
    end
  end
end
