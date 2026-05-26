class CreateHermitAppearances < ActiveRecord::Migration[8.0]
  def change
    create_table :hermit_appearances do |t|
      t.references :hermit_video, null: false, foreign_key: true
      t.references :hermit, null: false, foreign_key: true

      t.timestamps
    end
  end
end
