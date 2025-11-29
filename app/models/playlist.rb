class Playlist < ApplicationRecord
  has_many :playlist_songs, -> { order(position: :asc) }, dependent: :destroy
  has_many :songs, through: :playlist_songs

  validates :name, presence: true

  # Return songs in the order specified by position
  def ordered_songs
    songs.joins(:playlist_songs)
         .where(playlist_songs: { playlist_id: id })
         .order("playlist_songs.position ASC")
  end
end
