class PlaylistSong < ApplicationRecord
  belongs_to :playlist
  belongs_to :song

  validates :playlist_id, uniqueness: { scope: :song_id, message: "already contains this song" }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Auto-set position to end of playlist if not provided
  before_validation :set_position, on: :create

  private

  def set_position
    return if position.present?

    max_position = playlist.playlist_songs.maximum(:position) || -1
    self.position = max_position + 1
  end
end
