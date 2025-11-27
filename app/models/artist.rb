class Artist < ApplicationRecord
  has_one_attached :image
  has_one_attached :banner_video
  has_many :songs, dependent: :destroy, inverse_of: :artist
  has_many :albums, dependent: :destroy, inverse_of: :artist
  has_many :song_genres, through: :songs
  has_many :genres, through: :song_genres

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
