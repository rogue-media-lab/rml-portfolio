class UserHermitProfile < ApplicationRecord
  belongs_to :user
  belongs_to :favorite_hermit, class_name: "Hermit", optional: true

  validates :user_id, uniqueness: true
  validates :waitlist_status, inclusion: { in: %w[pending approved declined] }
end
