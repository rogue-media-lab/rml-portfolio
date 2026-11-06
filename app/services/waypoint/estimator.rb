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

    # Parts come from the shop's own parts list where it exists. There is no
    # vehicle-keyed parts catalog yet, so this stays deliberately conservative.
    def find_parts
      return [] unless defined?(CarUs::ShopPart)

      CarUs::ShopPart.where("name ILIKE ?", "%#{@service}%").limit(10).map do |p|
        {
          name: p.try(:name),
          part_number: p.try(:part_number),
          quantity: 1,
          unit_cost: p.try(:cost) || p.try(:unit_cost)
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
