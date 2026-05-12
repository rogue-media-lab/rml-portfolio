class Restaurant < ApplicationRecord
  has_many :menu_categories, dependent: :destroy
  has_many :menu_items, through: :menu_categories
  has_many :testimonials, dependent: :destroy
  has_many :hours, dependent: :destroy
  has_many :reservations, dependent: :destroy
  has_many :orders, dependent: :destroy

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }

  # For URL generation
  def to_param
    slug
  end
end
