class CarUs::FlashAlert < ApplicationRecord
  belongs_to :shop
  belongs_to :technician
  has_many :redemptions, as: :redeemable

  validates :title, presence: true
  validates :discount_percentage, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :duration_hours, presence: true,
            numericality: { greater_than: 0 }

  before_create :set_expiration
  before_create :generate_barcode

  scope :active_alerts, -> {
    where(active: true).where("expires_at > ?", Time.current)
  }

  def expired?
    expires_at < Time.current
  end

  def time_remaining
    return 0 if expired?
    (expires_at - Time.current).to_i
  end

  private

  def set_expiration
    self.expires_at = Time.current + duration_hours.hours
  end

  def generate_barcode
    self.code = "PCT#{discount_percentage}_#{SecureRandom.hex(4).upcase}"
  end
end