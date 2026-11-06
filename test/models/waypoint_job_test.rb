require "test_helper"

# A Waypoint quote that became a job. The interesting behaviour is not the columns -
# it is that a saved job stays correctable, and that a status means something.
class WaypointJobTest < ActiveSupport::TestCase
  def build(overrides = {})
    WaypointJob.new({
      service: "oil change",
      vehicle_year: 2020,
      vehicle_make: "gmc",
      vehicle_model: "sierra",
      mileage: 135_218,
      labor_hours: 0.3,
      labor_rate: 158.84,
      labor_total: 47.65,
      parts_total: 73.0,
      total: 120.65,
      parts: [
        { "name" => "8 quarts oil", "unit_cost" => 60.0, "quantity" => 1 },
        { "name" => "Oil filter", "part_number" => "PF63", "unit_cost" => 13.0, "quantity" => 1,
          "confidence" => "manual" }
      ],
      gaps: [ "no torque spec on file" ]
    }.merge(overrides))
  end

  # ---- validity -------------------------------------------------------------

  test "valid with valid attributes" do
    assert build.valid?
  end

  test "requires a service" do
    job = build(service: "")
    assert_not job.valid?
    assert_includes job.errors[:service], "can't be blank"
  end

  test "rejects an unknown status" do
    assert_not build(status: "invoiced").valid?
  end

  test "rejects an unknown door" do
    assert_not build(door: "carrier_pigeon").valid?
  end

  test "defaults to quoted and the app door" do
    job = build
    job.save!
    assert_equal "quoted", job.status
    assert_equal "app", job.door
  end

  # ---- a status has to mean something ---------------------------------------

  test "stamps quoted_at on create" do
    job = build
    assert_nil job.quoted_at
    job.save!
    assert_not_nil job.quoted_at
  end

  test "marking paid stamps both dates" do
    job = build
    job.save!
    job.mark_paid!

    assert_equal "paid", job.status
    assert_not_nil job.paid_on
    assert_not_nil job.completed_at
  end

  # The regression that started this test: setting status by string from the API
  # bypassed mark_paid! and left a job marked paid with no paid date.
  test "setting status by string stamps the same dates as mark_paid!" do
    job = build
    job.save!
    job.update!(status: "paid")

    assert_not_nil job.paid_on, "a paid job with no paid_on cannot be reported on"
    assert_not_nil job.completed_at
  end

  test "done stamps completion but not payment" do
    job = build
    job.save!
    job.update!(status: "done")

    assert_not_nil job.completed_at
    assert_nil job.paid_on
  end

  test "un-paying clears the paid date" do
    job = build
    job.save!
    job.update!(status: "paid")
    assert_not_nil job.paid_on

    job.update!(status: "quoted")
    assert_nil job.paid_on, "a job that is no longer paid must not keep a paid date"
    assert_nil job.completed_at
  end

  # ---- the money ------------------------------------------------------------

  test "collected counts only paid jobs and outstanding counts the rest" do
    WaypointJob.delete_all
    build(total: 100, status: "paid").save!
    build(total: 50, status: "done").save!
    build(total: 25, status: "quoted").save!

    assert_equal 100, WaypointJob.collected_total.to_f
    assert_equal 75, WaypointJob.outstanding_total.to_f
  end

  # ---- reopening a job in the editor ----------------------------------------

  # to_draft is what lets the Recent list reopen a logged job in the same card the
  # capture flow uses. If it drifts from that shape, editing silently breaks.
  test "to_draft returns the shape the capture card speaks" do
    job = build
    job.save!
    draft = job.to_draft

    assert_equal %i[parsed estimate], draft.keys

    assert_equal 2020, draft[:parsed][:year]
    assert_equal "gmc", draft[:parsed][:make]
    assert_equal "sierra", draft[:parsed][:model]
    assert_equal 135_218, draft[:parsed][:mileage]
    assert_equal "2020 gmc sierra", draft[:parsed][:vehicle]

    assert_equal "oil change", draft[:estimate][:service]
    assert_equal 2, draft[:estimate][:parts].length
    assert_equal 73.0, draft[:estimate][:parts_total]
    assert_equal 120.65, draft[:estimate][:total]
    assert_equal [ "no torque spec on file" ], draft[:estimate][:gaps]
  end

  test "to_draft survives a job with nothing filled in" do
    job = WaypointJob.create!(service: "brake job")
    draft = job.to_draft

    assert_equal [], draft[:estimate][:parts]
    assert_equal [], draft[:estimate][:gaps]
    assert_nil draft[:estimate][:total]
    assert_nil draft[:parsed][:vehicle]
  end

  test "vehicle_label joins what is present and stays nil when nothing is" do
    assert_equal "2020 gmc sierra", build.vehicle_label
    assert_equal "gmc sierra", build(vehicle_year: nil).vehicle_label
    assert_nil build(vehicle_year: nil, vehicle_make: nil, vehicle_model: nil).vehicle_label
  end
end
