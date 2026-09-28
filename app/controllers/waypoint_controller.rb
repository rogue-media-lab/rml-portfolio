class WaypointController < ApplicationController
  # Demo view — renders a Discord-look mockup of the #waypoint channel.
  # No model, no DB, no auth. Fake data only.
  def index
    @active_thread = "brakes"
    @active_channel = "welcome-and-about"
  end

  # Turbo frame responses — return only the thread content
  def welcome; end
  def brakes; end
  def radiator; end
  def labs_lounge; end
end
