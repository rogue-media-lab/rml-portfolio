class CarUs::BookingRequest < ApplicationRecord
  belongs_to :vehicle, class_name: "CarUs::Vehicle"

  validates :service_type, :preferred_date, presence: true

  scope :upcoming, -> { where("preferred_date >= ?", Date.today).order(preferred_date: :asc) }
end