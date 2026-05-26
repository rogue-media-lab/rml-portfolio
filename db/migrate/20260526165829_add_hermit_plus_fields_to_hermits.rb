class AddHermitPlusFieldsToHermits < ActiveRecord::Migration[8.0]
  def change
    add_column :hermits, :from, :string unless column_exists?(:hermits, :from)
    add_column :hermits, :skin_url, :string unless column_exists?(:hermits, :skin_url)
    add_column :hermits, :face_url, :string unless column_exists?(:hermits, :face_url)
    add_column :hermits, :alias_image_url, :string unless column_exists?(:hermits, :alias_image_url)
    add_column :hermits, :info2, :text unless column_exists?(:hermits, :info2)
    add_column :hermits, :slug, :string unless column_exists?(:hermits, :slug)
    add_index :hermits, :slug, unique: true unless index_exists?(:hermits, :slug)
  end
end
