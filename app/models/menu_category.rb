class MenuCategory < ApplicationRecord
  belongs_to :restaurant
  has_many :menu_items, dependent: :destroy

  scope :active, -> { where(active: true) }
  scope :sorted, -> { order(:sort_order) }

  validates :name, presence: true
end
