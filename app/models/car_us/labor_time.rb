class CarUs::LaborTime < ApplicationRecord
  validates :service, :hours, presence: true
  scope :by_category, -> { order(:category, :service) }
end
