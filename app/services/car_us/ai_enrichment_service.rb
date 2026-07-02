# Enriches decoded vehicle data with AI specs and suggestions.
# Cached per VIN — each vehicle enriched exactly once, forever.
# Uses the same model as ChatService for consistency.
#
# Usage:
#   service = CarUs::AiEnrichmentService.new(vin: "1HG...", decoded: {...}, notes: "oil change")
#   result  = service.enrich
#
class CarUs::AiEnrichmentService
  OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
  MODEL = "qwen/qwen3.7-plus"

  def initialize(vin:, decoded:, notes: "")
    @vin = vin
    @decoded = decoded
    @notes = notes
  end

  def enrich
    return nil if @vin.blank?

    # Only cache positive results — don't cache template/default values
    cached = Rails.cache.read("ai_enrich/#{@vin}")
    return cached if cached.present? && !template_response?(cached)

    result = call_openrouter
    if result.present? && !template_response?(result)
      Rails.cache.write("ai_enrich/#{@vin}", result, expires_in: 365.days)
    end
    result
  end

  private

  def call_openrouter
    api_key = ENV["OPENROUTER_API_KEY"] || Rails.application.credentials.dig(:openrouter, :api_key)
    return basic_enrichment unless api_key

    prompt = <<~PROMPT
      You are an automotive technician assistant. Look up the exact specifications for this specific vehicle. Return ONLY valid JSON (no markdown, no backticks, no example values — use REAL data):

      {
        "specs": {
          "oil_weight": "the correct oil viscosity",
          "oil_capacity_qts": number,
          "oil_filter": "the correct OEM filter part number",
          "drain_plug_torque_ft_lbs": number,
          "coolant_type": "the correct coolant specification",
          "transmission_fluid": "the correct transmission fluid specification",
          "spark_plug": "the correct OEM spark plug part number",
          "tire_pressure_f": number,
          "tire_pressure_r": number
        },
        "service_suggestions": ["real service suggestions based on this vehicle"],
        "plain_english": "A 2-sentence summary of this vehicle for a customer.",
        "difficulty_notes": "Any known pain points, common issues, or special tool requirements for this vehicle."
      }

      Vehicle to look up:
      - VIN: #{@vin}
      - Year: #{@decoded[:year]}
      - Make: #{@decoded[:make]}
      - Model: #{@decoded[:model]}
      - Engine: #{@decoded[:engine_size]}
      - Transmission: #{@decoded[:transmission]}
      - Notes: #{@notes}

      IMPORTANT: Use the CORRECT specs for this exact vehicle. Do NOT use placeholder or example values. If you are unsure about a field, leave it as null rather than guessing.
    PROMPT

    body = {
      model: MODEL,
      messages: [ { role: "user", content: prompt } ],
      max_tokens: 800
    }

    response = Net::HTTP.post(
      URI(OPENROUTER_URL),
      body.to_json,
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{api_key}",
        "HTTP-Referer" => "https://carus.app",
        "X-Title" => "CarUs"
      }
    )

    return basic_enrichment unless response.code.to_i == 200

    data = JSON.parse(response.body)
    raw = data.dig("choices", 0, "message", "content") || "{}"
    raw = raw.gsub(/\A```(?:json)?\s*/, "").gsub(/\s*```\z/, "")
    JSON.parse(raw)
  rescue => e
    Rails.logger.error("AiEnrichmentService error: #{e.message}")
    basic_enrichment
  end

  # Detect template/default responses where the model copied the prompt examples
  def template_response?(result)
    specs = result["specs"] || {}
    return true if specs.values.any? { |v| v.to_s.include?("e.g.") || v.to_s.include?("the correct") }
    false
  end

  def basic_enrichment
    {
      "specs" => {},
      "service_suggestions" => [],
      "plain_english" => "#{@decoded[:year]} #{@decoded[:make]} #{@decoded[:model]} — specs unavailable.",
      "difficulty_notes" => ""
    }
  end
end
