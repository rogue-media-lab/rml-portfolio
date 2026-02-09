class CreateSoundcloudTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :soundcloud_tokens do |t|
      t.text :access_token
      t.text :refresh_token
      t.integer :expires_at
      t.string :client_id

      t.timestamps
    end
  end
end