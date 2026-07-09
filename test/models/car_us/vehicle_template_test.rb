require "test_helper"

class CarUs::VehicleTemplateTest < ActiveSupport::TestCase
  setup do
    @civic = CarUs::VehicleTemplate.new(
      make: "Honda",
      model: "Civic",
      year: 2018,
      engine_size: "2.0L I4",
      oil_weight: "0W-20",
      oil_capacity_qts: 3.7,
      oil_filter_oem: "15400-PLM-A02",
      cabin_air_filter_oem: "80292-T2A-A01",
      engine_air_filter_oem: "17220-5A2-A00"
    )
  end

  # ── Validations ──────────────────────────────────────────

  test "valid with required fields" do
    assert @civic.valid?
  end

  test "invalid without make" do
    @civic.make = nil
    assert_not @civic.valid?
    assert_includes @civic.errors[:make], "can't be blank"
  end

  test "invalid without model" do
    @civic.model = nil
    assert_not @civic.valid?
  end

  test "invalid without year" do
    @civic.year = nil
    assert_not @civic.valid?
  end

  test "default source is ai_generated" do
    assert_equal "ai_generated", @civic.source
  end

  test "source must be valid" do
    @civic.source = "invalid_value"
    assert_not @civic.valid?
  end

  # ── Scopes ───────────────────────────────────────────────

  test "for_vehicle matches on make, model, year, engine_size" do
    @civic.save!

    vehicle = CarUs::Vehicle.new(
      make: "Honda", model: "Civic", year: 2018, engine_size: "2.0L I4"
    )
    match = CarUs::VehicleTemplate.for_vehicle(vehicle).first
    assert_equal @civic, match
  end

  test "for_vehicle does not match different engine" do
    @civic.save!

    vehicle = CarUs::Vehicle.new(
      make: "Honda", model: "Civic", year: 2018, engine_size: "1.5T"
    )
    assert_empty CarUs::VehicleTemplate.for_vehicle(vehicle)
  end

  test "for_vehicle does not match different year" do
    @civic.save!

    vehicle = CarUs::Vehicle.new(
      make: "Honda", model: "Civic", year: 2020, engine_size: "2.0L I4"
    )
    assert_empty CarUs::VehicleTemplate.for_vehicle(vehicle)
  end

  # ── Predicates ───────────────────────────────────────────

  test "ai_generated? returns true when source is ai_generated" do
    assert @civic.ai_generated?
    assert_not @civic.shop_curated?
  end

  test "shop_curated? returns true when source is shop_curated" do
    @civic.source = "shop_curated"
    assert @civic.shop_curated?
    assert_not @civic.ai_generated?
  end

  test "verified? when verified_by_shop is set" do
    assert_not @civic.verified?
    @civic.verified_by_shop = CarUs::Shop.new(name: "Midas Rock Hill")
    assert @civic.verified?
  end

  # ── Matching ─────────────────────────────────────────────

  test "matches_vehicle? returns true for identical vehicle" do
    vehicle = CarUs::Vehicle.new(
      make: "Honda", model: "Civic", year: 2018, engine_size: "2.0L I4"
    )
    assert @civic.matches_vehicle?(vehicle)
  end

  test "matches_vehicle? returns false for different engine" do
    vehicle = CarUs::Vehicle.new(
      make: "Honda", model: "Civic", year: 2018, engine_size: "1.5T"
    )
    assert_not @civic.matches_vehicle?(vehicle)
  end

  # ── Uniqueness ───────────────────────────────────────────

  test "unique index prevents duplicate make/model/year/engine" do
    @civic.save!

    duplicate = CarUs::VehicleTemplate.new(
      make: "Honda", model: "Civic", year: 2018, engine_size: "2.0L I4"
    )
    assert_not duplicate.valid?
  end
end
