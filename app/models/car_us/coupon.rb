class CarUs::Coupon < ApplicationRecord
  belongs_to :shop, optional: true  # generic coupons are not shop-locked

  validates :code, presence: true

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
end
