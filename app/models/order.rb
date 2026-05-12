class Order < ApplicationRecord
  belongs_to :restaurant
  has_many :order_items, dependent: :destroy

  scope :pending, -> { where(status: "pending") }

  validates :customer_name, :phone, :total, presence: true
end
