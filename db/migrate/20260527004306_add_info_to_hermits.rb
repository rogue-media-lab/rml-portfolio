class AddInfoToHermits < ActiveRecord::Migration[8.0]
  def change
    add_column :hermits, :info, :text
  end
end
