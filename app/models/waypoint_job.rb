# frozen_string_literal: true

# A Waypoint quote that became a job.
#
# Standalone on purpose - a quote exists before there is a shop, a technician or a
# vehicle record. See the migration for why it does not hang off car_us_service_jobs.
class WaypointJob < ApplicationRecord
  DOORS   = %w[app sms voice discord].freeze
  STATUSES = %w[quoted done paid].freeze

  validates :service, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :door, inclusion: { in: DOORS }

  before_validation :stamp_quoted_at, on: :create

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

  def vehicle_label
    [ vehicle_year, vehicle_make, vehicle_model ].compact_blank.join(" ").presence
  end

  def mark_done!
    update!(status: "done", completed_at: Time.current)
  end

  def mark_paid!
    update!(status: "paid", completed_at: completed_at || Time.current, paid_on: Time.current)
  end

  private

  def stamp_quoted_at
    self.quoted_at ||= Time.current
  end
end
