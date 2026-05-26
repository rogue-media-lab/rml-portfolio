class WatchProgress < ApplicationRecord
  belongs_to :user
  belongs_to :hermit_video

  validates :user_id, uniqueness: { scope: :hermit_video_id }
  validates :progress_seconds, numericality: { greater_than_or_equal_to: 0 }
end
