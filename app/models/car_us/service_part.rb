# frozen_string_literal: true

class CarUs::ServicePart < ApplicationRecord
  # A part a service needs, for a vehicle or for any vehicle.
  #
  # Distinct from CarUs::ShopPart, which is a shop's preferred brand for a consumable
  # category on one model year. This is "what parts does this job take", and it covers
  # repair parts - alternators, starters, water pumps - which ShopPart's closed
  # CATEGORIES list cannot represent.
  #
  # Part numbers are vehicle-specific in a way labor times are not: an alternator for a
  # 1.5T Escape is not the alternator for the 2.5. So the vehicle scope matters here more
  # than it does for labor, and a generic row is a weaker claim than a scoped one.
  CONFIDENCE_LEVELS = %w[verified_on_vehicle corroborated single_source inferred].freeze

  validates :service, :part_name, presence: true

  scope :for_service, ->(name) { where("service ILIKE ?", "%#{name}%") }
  scope :generic, -> { where(make: nil, model: nil) }

  # Vehicle-specific rows first, generic as the fallback - same precedence as labor.
  scope :for_vehicle, ->(make, model, year) {
    if make.present? && model.present?
      scoped = where("make ILIKE ? AND model ILIKE ?", make, model)
      if year.present?
        scoped = scoped.where(
          "(year_start IS NULL OR year_start <= ?) AND (year_end IS NULL OR year_end >= ?)",
          year, year
        )
      end
      scoped
    else
      none
    end
  }
end
