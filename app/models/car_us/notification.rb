class CarUs::Notification < ApplicationRecord
  belongs_to :car_owner

  validates :title, presence: true
  scope :unread, -> { where(read: false).order(created_at: :desc) }
  scope :recent, -> { order(created_at: :desc).limit(20) }
end
