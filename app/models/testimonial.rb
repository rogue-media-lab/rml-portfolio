class Testimonial < ApplicationRecord
  belongs_to :restaurant

  scope :active, -> { where(active: true) }
  scope :featured, -> { where(featured: true) }

  validates :customer_name, :quote, presence: true
end
