class CarUs::JobPart < ApplicationRecord
  belongs_to :service_job, class_name: "CarUs::ServiceJob"

  validates :name, presence: true
  validates :quantity, numericality: { greater_than: 0 }
end
