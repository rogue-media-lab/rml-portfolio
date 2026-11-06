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
  # The money and today panels are computed from waypoint_jobs, never from markup.
  def app
    @specs = SPEC_SEED
    @labor_rate = CarUs::Shop.first&.labor_rate || CarUs::Shop::DEFAULT_LABOR_RATE

    @jobs_today      = WaypointJob.today.recent
    @collected_total = WaypointJob.collected_total
    @outstanding_total = WaypointJob.outstanding_total
    @paid_count      = WaypointJob.paid.count
    @total_count     = WaypointJob.count
    @recent_jobs     = WaypointJob.recent.limit(6)
  end

  # POST /waypoint/log — turn a quote into a record.
  # The estimate snapshot comes back with the request so the row freezes the price
  # that was actually offered, rather than re-deriving it and silently repricing.
  def log
    job = WaypointJob.new(job_params.merge(door: "app"))

    if job.save
      render json: job_response(job), status: :created
    else
      render json: { ok: false, errors: job.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # PATCH /waypoint/jobs/:id - a repair order is wrong the moment it is saved.
  # The mileage arrives later, a filter gets added, the customer pays. Amending it
  # is the normal case, not an exception.
  def update
    job = WaypointJob.find(params[:id])

    if job.update(job_params)
      render json: job_response(job)
    else
      render json: { ok: false, errors: job.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # GET /waypoint/estimate?service=alternator&make=ford&model=escape&year=2021&mileage=84000
  #
  # The quote. Labor comes from car_us_labor_times (vehicle-specific row wins over the
  # generic one), parts from the shop's parts list, torque from car_us_torque_specs.
  # Anything missing comes back as a gap rather than a guess.
  def estimate
    result = Waypoint::Estimator.new(
      service: params[:service],
      make: params[:make],
      model: params[:model],
      year: params[:year],
      mileage: params[:mileage],
      rate: params[:rate]
    ).call

    render json: result.to_h
  end

  private

  def job_params
    # door is not permitted - it records how the job arrived and must not be
    # rewritten by an edit that came from the app.
    params.require(:job).permit(
      :service, :vehicle_year, :vehicle_make, :vehicle_model, :mileage,
      :labor_hours, :labor_rate, :labor_total, :parts_total, :total,
      :raw_capture, :status, :notes,
      parts:  %i[name part_number oem_number brand quantity unit_cost confidence verified_on_vehicle],
      torque: %i[fastener value unit confidence],
      gaps:   []
    )
  end

  def job_response(job)
    {
      ok: true,
      id: job.id,
      total: job.total.to_f,
      status: job.status,
      draft: job.to_draft,
      collected_total: WaypointJob.collected_total.to_f,
      outstanding_total: WaypointJob.outstanding_total.to_f,
      job_count: WaypointJob.count
    }
  end

  public

  # Turbo frame responses — return only the thread content
  def welcome; end
  def brakes; end
  def radiator; end
  def labs_lounge; end
end
