class CarUs::ServiceJob < ApplicationRecord
  belongs_to :vehicle, class_name: "CarUs::Vehicle"
  belongs_to :technician
  has_many :job_parts, class_name: "CarUs::JobPart", dependent: :destroy

  validates :description, presence: true
  validates :book_hours, numericality: { greater_than: 0 }, allow_nil: true

  scope :recent, -> { order(created_at: :desc).limit(10) }
  scope :completed, -> { where(status: "completed") }
  scope :open, -> { where(status: "open") }
  scope :this_week, -> { where(created_at: Date.today.all_week) }
  scope :this_month, -> { where(created_at: Date.today.all_month) }

  def completed?
    status == "completed"
  end

  def open?
    status == "open"
  end

  def complete!(hours = nil)
    attrs = { status: "completed", completed_at: Time.current }
    attrs[:book_hours] = hours if hours&.positive?
    update!(attrs)
  end
end
