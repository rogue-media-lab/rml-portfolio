class CreateCustomSoundCloudArtworks < ActiveRecord::Migration[8.0]
  def change
    create_table :custom_sound_cloud_artworks do |t|
      t.string :soundcloud_track_id
      t.string :track_title
      t.string :track_artist

      t.timestamps
    end
    add_index :custom_sound_cloud_artworks, :soundcloud_track_id, unique: true
  end
end
