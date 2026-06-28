class CarUs::Redemption < ApplicationRecord
  belongs_to :redeemable, polymorphic: true
  belongs_to :car_owner
  belongs_to :shop
  belongs_to :technician, optional: true

  scope :completed, -> { where.not(redeemed_at: nil) }
  scope :pending, -> { where(redeemed_at: nil) }
end
