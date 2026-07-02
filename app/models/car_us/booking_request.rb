class CarUs::BookingRequest < ApplicationRecord
  belongs_to :vehicle, class_name: "CarUs::Vehicle"
  belongs_to :technician, optional: true
  belongs_to :flash_alert, optional: true

  validates :service_types, :preferred_date, presence: true

  scope :upcoming, -> { where("preferred_date >= ?", Date.today).order(preferred_date: :asc) }
  scope :unnotified, -> { where(shop_notified_at: nil) }
end
