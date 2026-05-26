class CreateHermitCrewMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :hermit_crew_memberships do |t|
      t.references :hermit_crew, null: false, foreign_key: true
      t.references :hermit, null: false, foreign_key: true

      t.timestamps
    end
  end
end
