class CarUs::Shop < ApplicationRecord
  has_many :car_owners, dependent: :nullify
  has_many :technicians, dependent: :destroy
  has_many :flash_alerts, dependent: :destroy
  has_many :redemptions, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :coupons, dependent: :destroy

  validates :name, presence: true
end
