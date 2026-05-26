class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :hermit_video

  validates :user_id, uniqueness: { scope: :hermit_video_id }
end
