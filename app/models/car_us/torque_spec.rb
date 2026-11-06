class CarUs::TorqueSpec < ApplicationRecord
  # Keyed to the COMPONENT, not the vehicle. Alternator mounting bolts are largely the
  # same value across a platform, so one row per fastener covers many cars - which is
  # what makes this catalog cheap to curate and reusable across every vehicle.
  #
  # Values are safety-critical. Never seed a number here that did not come from a real
  # source; a wrong torque strips a bolt or loses a wheel.
  CONFIDENCE_LEVELS = %w[verified_on_vehicle corroborated single_source].freeze

  validates :component, :fastener, :value, :unit, presence: true
  validates :component, uniqueness: { scope: :fastener }

  scope :for_component, ->(name) { where("component ILIKE ?", "%#{name}%") }
end
