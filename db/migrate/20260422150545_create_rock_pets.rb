class CreateRockPets < ActiveRecord::Migration[8.0]
  def change
    create_table :rock_pets do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :level, default: 1
      t.integer :xp, default: 0
      t.integer :xp_to_next_level, default: 100
      t.string :stage, default: "egg"
      t.jsonb :personality_attributes, default: {}
      t.jsonb :skills_learned, default: []
      t.jsonb :achievements, default: []
      t.integer :total_messages, default: 0
      t.integer :total_conversations, default: 0
      t.integer :total_words, default: 0
      t.datetime :last_interaction_at
      t.string :nickname

      t.timestamps
    end

    add_index :rock_pets, :stage
    add_index :rock_pets, :level
  end
end
