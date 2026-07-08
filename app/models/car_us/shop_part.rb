# frozen_string_literal: true

class CarUs::ShopPart < ApplicationRecord
  belongs_to :shop, class_name: "CarUs::Shop"
  belongs_to :vehicle_template, class_name: "CarUs::VehicleTemplate", optional: true

  validates :part_category, :shop_number, presence: true
  validates :part_category, uniqueness: {
    scope: [:shop_id, :vehicle_template_id],
    message: "already has a default for this shop and vehicle type"
  }

  scope :for_template, ->(template) { where(vehicle_template: template) }
  scope :for_shop, ->(shop) { where(shop: shop) }
  scope :by_category, -> { order(:part_category) }

  # Categories mirror what techs actually look up
  CATEGORIES = %w[
    oil_filter cabin_air_filter engine_air_filter
    spark_plug oil_brand coolant_brand
    trans_fluid_brand brake_fluid_brand
    wiper_blades battery serpentine_belt
  ].freeze

  validates :part_category, inclusion: { in: CATEGORIES }
end