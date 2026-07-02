# Orchestrates the full vehicle intake pipeline for technicians:
# 1. Photo → VIN (OpenRouter vision)
# 2. VIN → decoded specs (NHTSA vPIC)
# 3. Everything → AI enrichment (OpenRouter)
# 4. Save to database
#
# Usage:
#   result = CarUs::VehicleIntakeService.new(
#     photo: params[:photo],
#     notes: params[:notes],
#     technician: current_technician
#   ).call
#
#   result[:vehicle]  # => CarUs::Vehicle (persisted)
#   result[:enriched] # => AI-generated specs hash
#   result[:vin]      # => extracted VIN string
#
class CarUs::VehicleIntakeService
  # If photo is provided, vision extracts VIN from it first.
  # Manual VIN always takes priority if both are provided.
  def initialize(photo:, vin:, notes:, technician:)
    @photo = photo
    @manual_vin = vin
    @notes = notes
    @technician = technician
  end

  def call
    # Step 1: Get VIN — manual entry first, photo extraction as fallback
    vin = @manual_vin.presence || extract_vin
    return { error: "No VIN provided. Enter manually or snap a photo.", vin: nil } unless vin.present?

    # Clean up the VIN
    vin = vin.strip.upcase.gsub(/[^A-HJ-NPR-Z0-9]/, "")
    return { error: "Invalid VIN format. Should be 17 characters.", vin: vin } unless vin.length == 17

    # Step 2: Decode VIN via NHTSA
    decoded = CarUs::Vehicle.decode_vin(vin)
    return { error: "VIN #{vin} not found in NHTSA database.", vin: vin } if decoded.blank? || decoded[:make].blank?

    # Step 3: AI enrichment
    enriched = CarUs::AiEnrichmentService.new(
      vin: vin,
      decoded: decoded.merge(mileage: @notes.to_s),
      notes: @notes
    ).enrich

    # Step 4: Save to database
    vehicle = create_vehicle(vin, decoded, enriched)

    { vehicle: vehicle, enriched: enriched, vin: vin }
  end

  private

  def extract_vin
    if @photo.present?
      CarUs::VinVisionService.new(@photo).extract
    else
      nil
    end
  end

  def create_vehicle(vin, decoded, enriched)
    specs = enriched&.dig("specs") || {}

    CarUs::Vehicle.find_or_create_by!(vin: vin) do |v|
      v.year          = decoded[:year]
      v.make          = decoded[:make]
      v.model         = decoded[:model]
      v.trim          = decoded[:trim]
      v.engine_size   = decoded[:engine_size] || specs["oil_weight"]
      v.transmission  = decoded[:transmission]
      v.ai_specs      = specs.to_json
      v.ai_suggestions = enriched&.dig("service_suggestions")&.to_json
      v.ai_plain_english = enriched&.dig("plain_english")
      v.ai_difficulty_notes = enriched&.dig("difficulty_notes")
      v.last_lookup_at = Time.current
      v.looked_up_by   = @technician&.id
    end
  end
end
