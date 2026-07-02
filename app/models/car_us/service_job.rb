class CarUs::ServiceJob < ApplicationRecord
  belongs_to :vehicle, class_name: "CarUs::Vehicle"
  belongs_to :technician
  has_many :job_parts, class_name: "CarUs::JobPart", dependent: :destroy

  validates :description, presence: true
  validates :book_hours, numericality: { greater_than: 0 }, allow_nil: true

  scope :recent, -> { order(created_at: :desc).limit(10) }
  scope :completed, -> { where(status: "completed") }

  def completed?
    status == "completed"
  end
end
