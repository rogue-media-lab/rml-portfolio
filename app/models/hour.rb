class Hour < ApplicationRecord
  belongs_to :restaurant

  scope :ordered, -> { order(:day_of_week) }

  DAYS = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].freeze

  def day_name
    DAYS[day_of_week] || "Unknown"
  end
end
