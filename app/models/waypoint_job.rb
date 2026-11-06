# frozen_string_literal: true

# A Waypoint quote that became a job.
#
# Standalone on purpose - a quote exists before there is a shop, a technician or a
# vehicle record. See the migration for why it does not hang off car_us_service_jobs.
class WaypointJob < ApplicationRecord
  DOORS   = %w[app sms voice discord].freeze
  STATUSES = %w[quoted done paid].freeze

  VIN_FORMAT = /\A[A-HJ-NPR-Z0-9]{17}\z/

  validates :service, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :door, inclusion: { in: DOORS }

  # A VIN that is not a VIN is worse than no VIN: it looks like a key and opens nothing.
  # Real VINs exclude I, O and Q, so a 17-character string containing one is a part
  # number that wandered into the wrong field.
  validates :vin, format: { with: VIN_FORMAT, message: "must be 17 characters, no I, O or Q" },
                  allow_blank: true

  before_validation :stamp_quoted_at, on: :create
  before_validation :normalize_identity
  before_save :stamp_status_dates

  scope :recent, -> { order(created_at: :desc) }
  scope :paid,   -> { where(status: "paid") }
  scope :unpaid, -> { where(status: %w[quoted done]) }
  scope :today,  -> { where(created_at: Date.current.all_day) }

  # The money screen. Computed from rows, never from markup.
  def self.collected_total
    paid.sum(:total)
  end

  def self.outstanding_total
    unpaid.sum(:total)
  end

  # The shape the capture card already speaks ({parsed, estimate}). A logged job
  # reopens in the same editor rather than a second one that drifts out of sync.
  def to_draft
    {
      parsed: {
        year: vehicle_year,
        make: vehicle_make,
        model: vehicle_model,
        service: service,
        mileage: mileage,
        vehicle: vehicle_label,
        vin: vin,
        plate: plate,
        plate_state: plate_state,
        engine: vehicle_engine,
        color: vehicle_color,
        customer: {
          name: customer_name,
          phone: customer_phone,
          address: customer_address
        },
        raw: raw_capture
      },
      estimate: {
        service: service,
        labor_hours: labor_hours&.to_f,
        labor_rate: labor_rate&.to_f,
        labor_total: labor_total&.to_f,
        parts_total: parts_total&.to_f,
        total: total&.to_f,
        mileage: mileage,
        parts: parts || [],
        torque: torque || [],
        gaps: gaps || []
      }
    }
  end

  def vehicle_label
    [ vehicle_year, vehicle_make, vehicle_model ].compact_blank.join(" ").presence
  end

  def mark_done!
    update!(status: "done")
  end

  def mark_paid!
    update!(status: "paid")
  end

  private

  def stamp_quoted_at
    self.quoted_at ||= Time.current
  end

  # Identity fields are stored in one shape whatever the source: a plate read off a phone
  # camera, spoken aloud, or typed by hand should not produce three spellings of one car.
  def normalize_identity
    self.vin = vin.to_s.upcase.gsub(/[^A-Z0-9]/, "").presence
    self.plate = plate.to_s.upcase.gsub(/[^A-Z0-9]/, "").presence
    self.plate_state = plate_state.to_s.upcase.presence

    self.vehicle_make = vehicle_make.to_s.downcase.strip.presence
    self.vehicle_model = vehicle_model.to_s.downcase.strip.presence
    self.vehicle_color = vehicle_color.to_s.downcase.strip.presence
    self.vehicle_engine = vehicle_engine.to_s.strip.presence
  end

  # Status carries dates. Setting it by string from the API has to stamp them exactly
  # as mark_paid! does, or "paid" becomes a label with nothing behind it and the books
  # cannot answer when the money actually arrived. Un-paying clears them again, because
  # a job that is no longer paid should not still carry a paid date.
  def stamp_status_dates
    return unless status_changed?

    if %w[done paid].include?(status)
      self.completed_at ||= Time.current
    else
      self.completed_at = nil
    end

    self.paid_on = status == "paid" ? (paid_on || Time.current) : nil
  end
end
