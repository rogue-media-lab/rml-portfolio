class WaypointController < ApplicationController
  # Demo views — no model, no DB, no auth. Fake data only.
  #
  # Two doors into the same idea, deliberately kept side by side:
  #   index  -> Discord-look channel mockup ("talk to it where you already are")
  #   app    -> the capture surface itself ("talk to it standing at the car")
  #
  # Seed specs are hardcoded while the reference tables live only in the local
  # SQLite working copy. car_us_labor_times and car_us_part_cross_references are
  # already in this app's Postgres; vehicle_specs / fluid_specs / transmission_specs
  # are not yet. When they land, @specs comes from the table and this constant goes.
  SPEC_SEED = [
    {
      code: "RE0F10A", name: "NISSAN NS-3", conf: "corroborated",
      note: "CVT fluid. Also covers RE0F10B, RE0F10E, RE0F10H, RE0F10J, RE0F11A, RE0F02H."
    },
    {
      code: "RE0F11A", name: "NISSAN NS-3", conf: "corroborated",
      note: "CVT fluid. Same family as RE0F10A."
    },
    {
      code: "2013 HYUNDAI SONATA 2.4", name: "5W-20 - 4.8 qt", conf: "verified on vehicle",
      note: "Confirmed in the bay. Filter crosses to OEM 26300-35505."
    },
    {
      code: "2018 FORD ESCAPE 1.5T", name: "5W-20 - 4.3 qt", conf: "single source",
      note: "Owner's manual only. Not yet confirmed on a car - treat as provisional."
    },
    {
      code: "2019 NISSAN ROGUE", name: nil, conf: "none",
      note: "No 2019 Rogue row. Nearby years exist (2011, 2015, 2017, 2023) but are not the same vehicle."
    }
  ].freeze

  def index
    @active_thread = "brakes"
    @active_channel = "welcome-and-about"
  end

  # The app door. One page, four panels, switched client-side.
  def app
    @specs = SPEC_SEED
  end

  # Turbo frame responses — return only the thread content
  def welcome; end
  def brakes; end
  def radiator; end
  def labs_lounge; end
end
