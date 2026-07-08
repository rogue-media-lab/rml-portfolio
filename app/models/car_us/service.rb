class CarUs::Service < ApplicationRecord
  belongs_to :shop

  validates :name, presence: true
  validates :duration_minutes, numericality: { greater_than: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
end
