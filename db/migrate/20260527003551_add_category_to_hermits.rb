class AddCategoryToHermits < ActiveRecord::Migration[8.0]
  def change
    add_column :hermits, :category, :string
  end
end
