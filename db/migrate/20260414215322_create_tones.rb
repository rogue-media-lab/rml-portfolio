class CreateTones < ActiveRecord::Migration[8.0]
  def change
    create_table :tones do |t|
      t.string :name, null: false
      t.text :description
      t.string :tags, array: true, default: []

      t.timestamps
    end
  end
end
