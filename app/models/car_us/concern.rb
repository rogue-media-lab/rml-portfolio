class CarUs::Concern < ApplicationRecord
  belongs_to :vehicle, class_name: "CarUs::Vehicle"

  validates :title, :severity, presence: true
  scope :active, -> { order(created_at: :desc) }
end
