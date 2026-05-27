class CreateWatchProgresses < ActiveRecord::Migration[8.0]
  def change
    create_table :watch_progresses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :hermit_video, null: false, foreign_key: true
      t.integer :progress_seconds, default: 0
      t.boolean :completed, default: false
      t.datetime :last_watched_at

      t.timestamps
    end

    add_index :watch_progresses, [ :user_id, :hermit_video_id ], unique: true
  end
end
