class CarUs::VehicleTemplate < ApplicationRecord
  belongs_to :verified_by_shop, class_name: "CarUs::Shop", optional: true

  validates :make, :model, :year, presence: true
  validates :source, inclusion: { in: %w[ai_generated shop_curated] }

  scope :for_vehicle, ->(vehicle) {
    where(
      make: vehicle.make,
      model: vehicle.model,
      year: vehicle.year,
      engine_size: vehicle.engine_size
    )
  }

  scope :by_mmy, -> { order(:make, :model, :year) }

  def ai_generated?
    source == "ai_generated"
  end

  def shop_curated?
    source == "shop_curated"
  end

  def verified?
    verified_by_shop_id.present?
  end

  # Matches a vehicle to this template — used for lookup
  def matches_vehicle?(vehicle)
    make == vehicle.make &&
      model == vehicle.model &&
      year == vehicle.year &&
      engine_size == vehicle.engine_size
  end
end