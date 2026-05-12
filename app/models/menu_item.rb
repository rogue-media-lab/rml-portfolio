class MenuItem < ApplicationRecord
  belongs_to :menu_category
  belongs_to :restaurant
  has_many :order_items, dependent: :destroy

  scope :active, -> { where(active: true) }
  scope :featured, -> { where(featured: true) }

  validates :name, :price, presence: true
end
