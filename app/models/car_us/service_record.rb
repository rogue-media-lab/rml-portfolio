class CarUs::ServiceRecord < ApplicationRecord
  belongs_to :vehicle, class_name: "CarUs::Vehicle"

  validates :service_date, :description, presence: true
  validates :cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :recent, -> { order(service_date: :desc) }
end
