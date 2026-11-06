module Waypoint
  # Turns (vehicle, service) into a quote: labor hours, parts, torque, total.
  #
  # The join is the product. Labor times, parts and torque all exist as separate
  # islands; this is the thing that answers "alternator on a 2021 Escape".
  #
  # Every gap is reported rather than filled. A missing part number or torque value
  # comes back as nil with a reason, because a plausible wrong number is worse than an
  # honest blank - especially for torque.
  class Estimator
    Result = Struct.new(
      :service, :labor_hours, :labor_source, :labor_rate, :labor_total,
      :parts, :parts_total, :torque, :mileage, :total, :gaps,
      keyword_init: true
    )

    def initialize(service:, make: nil, model: nil, year: nil, mileage: nil, rate: nil)
      @service = service.to_s.strip
      @make    = make.to_s.strip.presence
      @model   = model.to_s.strip.presence
      @year    = year.to_i.zero? ? nil : year.to_i
      @mileage = mileage.to_i.zero? ? nil : mileage.to_i
      @rate    = (rate.presence || default_rate).to_f
    end

    def call
      labor  = find_labor
      parts  = find_parts
      torque = find_torque

      labor_total = labor ? (labor.hours.to_f * @rate).round(2) : nil
      parts_total = parts.sum { |p| (p[:unit_cost].to_f * p[:quantity].to_i) }.round(2)

      gaps = []
      gaps << "no labor time on file for #{@service}" if labor.nil?
      gaps << "no parts on file for this service" if parts.empty?
      gaps << "no torque spec on file" if torque.empty?
      gaps << "mileage not given" if @mileage.nil?

      # Absent and zero are different values. Parts that have no cost must not total to
      # a silent $0.00, which reads as "free" - the same rule the capture parser follows
      # for a missing amount.
      uncosted = parts.count { |p| p[:unit_cost].nil? }
      if uncosted.positive?
        gaps << "#{uncosted} of #{parts.size} part(s) have no cost on file"
      end

      Result.new(
        service: @service,
        labor_hours: labor&.hours&.to_f,
        labor_source: labor ? (labor.make.present? ? "vehicle-specific" : "generic") : nil,
        labor_rate: @rate,
        labor_total: labor_total,
        parts: parts,
        parts_total: parts_total,
        torque: torque,
        mileage: @mileage,
        total: (labor_total.to_f + parts_total).round(2),
        gaps: gaps
      )
    end

    private

    def default_rate
      CarUs::Shop.first&.labor_rate || CarUs::Shop::DEFAULT_LABOR_RATE
    end

    # A vehicle-specific row wins over the generic one. That is the whole point of the
    # vehicle columns: 1.2h generally, 1.5h on a 2014 Avenger.
    def find_labor
      scope = CarUs::LaborTime.where("service ILIKE ?", "%#{@service}%")

      if @make && @model
        specific = scope.where("make ILIKE ? AND model ILIKE ?", @make, @model)
        if @year
          specific = specific.where(
            "(year_start IS NULL OR year_start <= ?) AND (year_end IS NULL OR year_end >= ?)",
            @year, @year
          )
        end
        found = specific.order(Arel.sql("year_start DESC NULLS LAST")).first
        return found if found
      end

      scope.where(make: nil).order(:hours).first
    end

    # Vehicle-specific parts win over generic, exactly like labor. A 1.5T Escape
    # alternator is not the 2.5 alternator, so a generic row is the weaker claim.
    def find_parts
      return [] unless defined?(CarUs::ServicePart)

      scope = CarUs::ServicePart.for_service(@service)
      rows = scope.for_vehicle(@make, @model, @year).to_a
      rows = scope.generic.to_a if rows.empty?

      rows.map do |p|
        {
          name: p.part_name,
          part_number: p.part_number,
          oem_number: p.oem_number,
          brand: p.brand,
          position: p.position,
          quantity: p.quantity.to_i.zero? ? 1 : p.quantity.to_i,
          unit_cost: p.unit_cost&.to_f,
          confidence: p.confidence,
          verified_on_vehicle: p.verified_on_vehicle
        }
      end
    rescue StandardError
      []
    end

    def find_torque
      return [] unless defined?(CarUs::TorqueSpec)

      CarUs::TorqueSpec.for_component(@service).map do |t|
        {
          fastener: t.fastener,
          value: t.value.to_f,
          unit: t.unit,
          confidence: t.confidence,
          verified_on_vehicle: t.verified_on_vehicle
        }
      end
    rescue StandardError
      []
    end
  end
end
