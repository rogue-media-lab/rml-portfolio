class HermitVideo < ApplicationRecord
  belongs_to :hermit
  has_many :hermit_appearances, dependent: :destroy
  has_many :appearing_hermits, through: :hermit_appearances, source: :hermit
  has_many :favorites, dependent: :destroy
  has_many :watch_progresses, dependent: :destroy

  has_rich_text :description

  validates :youtube_video_id, presence: true, uniqueness: true
  validates :title, presence: true
  validates :season, presence: true, numericality: { only_integer: true }
  validates :episode, presence: true, numericality: { only_integer: true }

  # Construct the YouTube video URL
  def youtube_url
    "https://youtu.be/#{youtube_video_id}"
  end

  # Construct the YouTube embed URL
  def youtube_embed_url
    "https://www.youtube.com/embed/#{youtube_video_id}"
  end
end
