class HermitAppearance < ApplicationRecord
  belongs_to :hermit_video
  belongs_to :hermit

  validates :hermit_id, uniqueness: { scope: :hermit_video_id }
end
