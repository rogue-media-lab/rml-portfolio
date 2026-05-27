class AddDescriptionToHermits < ActiveRecord::Migration[8.0]
  def change
    add_column :hermits, :description, :text
  end
end
