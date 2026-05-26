class CreateUserHermitProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :user_hermit_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :waitlist_status, default: "pending"
      t.references :favorite_hermit, null: true, foreign_key: { to_table: :hermits }
      t.boolean :notifications_enabled, default: true

      t.timestamps
    end
  end
end
