class CreatePlaylistSongs < ActiveRecord::Migration[8.0]
  def change
    create_table :playlist_songs do |t|
      t.references :playlist, null: false, foreign_key: true
      t.references :song, null: false, foreign_key: true
      t.integer :position

      t.timestamps
    end

    add_index :playlist_songs, [:playlist_id, :song_id], unique: true
    add_index :playlist_songs, :position
  end
end
