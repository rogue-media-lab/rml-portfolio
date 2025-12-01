class Album < ApplicationRecord
  has_one_attached :cover_art
  belongs_to :artist, optional: false
  belongs_to :genre, optional: true

  has_many :songs, dependent: :destroy, inverse_of: :album
  has_many :song_genres, through: :songs
  has_many :genres, through: :song_genres

  validates :title, presence: true
  validates :title, uniqueness: { scope: :artist_id, case_sensitive: false }

  # Ransack: Allow searching on specific attributes
  def self.ransackable_attributes(auth_object = nil)
    [ "title", "created_at", "updated_at" ]
  end
end
