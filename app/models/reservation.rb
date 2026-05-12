class Reservation < ApplicationRecord
  belongs_to :restaurant

  scope :pending, -> { where(status: "pending") }

  validates :customer_name, :phone, :party_size, :reservation_date, :reservation_time, presence: true
end
