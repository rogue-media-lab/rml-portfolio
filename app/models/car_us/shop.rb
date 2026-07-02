class CarUs::Shop < ApplicationRecord
  has_many :car_owners, dependent: :nullify
  has_many :technicians, dependent: :destroy
  has_many :flash_alerts, dependent: :destroy
  has_many :redemptions, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :coupons, dependent: :destroy

  validates :name, presence: true

  def to_param
    slug
  end

  # --- Settings accessors with defaults ---

  def tax_rate
    (settings["tax_rate"] || 0).to_f
  end

  def supplies_fee_enabled?
    settings["supplies_fee_enabled"] == true || settings["supplies_fee_enabled"] == "true"
  end

  def supplies_fee
    (settings["supplies_fee"] || 0).to_f
  end

  def travel_fee_enabled?
    settings["travel_fee_enabled"] == true || settings["travel_fee_enabled"] == "true"
  end

  def travel_fee
    (settings["travel_fee"] || 0).to_f
  end

  def travel_fee_label
    settings["travel_fee_label"].presence || "Travel Fee"
  end

  def max_bookings_per_slot
    (settings["max_bookings_per_slot"] || 3).to_i
  end

  # Bulk update settings from a params hash
  def update_settings(params)
    new_settings = settings.merge(params.to_h.symbolize_keys)
    update(settings: new_settings)
  end
end
