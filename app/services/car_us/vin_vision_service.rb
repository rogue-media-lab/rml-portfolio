# Extracts VIN from a vehicle photo using OpenRouter vision.
# Does NOT cache failures — only successful extractions.
#
class CarUs::VinVisionService
  OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

  def initialize(photo)
    @photo = photo
  end

  def extract
    return nil if @photo.blank?

    checksum = Digest::MD5.hexdigest(@photo.read)
    @photo.rewind

    # Check cache first — only positive hits
    cached = Rails.cache.read("vin_vision/#{checksum}")
    return cached if cached.present?

    result = call_openrouter
    Rails.cache.write("vin_vision/#{checksum}", result, expires_in: 365.days) if result.present?
    result
  end

  private

  def call_openrouter
    api_key = ENV["OPENROUTER_API_KEY"] || Rails.application.credentials.dig(:openrouter, :api_key)
    unless api_key
      Rails.logger.warn("VinVisionService: No OpenRouter API key (check credentials or ENV)")
      return nil
    end

    base64_image = Base64.strict_encode64(@photo.read)
    @photo.rewind
    mime = @photo.content_type || "image/jpeg"
    data_url = "data:#{mime};base64,#{base64_image}"

    body = {
      model: "deepseek/deepseek-v4-pro",
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: "Look at this photo and find the VIN (Vehicle Identification Number). It's a 17-character code on a metal plate or sticker, usually on the dashboard, door jamb, or engine bay. Return ONLY the VIN. If you can see a VIN but it's partially obscured, return what you can read. If there is no VIN visible, return 'NONE'." },
            { type: "image_url", image_url: { url: data_url } }
          ]
        }
      ],
      max_tokens: 30
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

    Rails.logger.info("VinVisionService: HTTP #{response.code}")

    return nil unless response.code.to_i == 200

    data = JSON.parse(response.body)
    raw = data.dig("choices", 0, "message", "content") || ""
    Rails.logger.info("VinVisionService: raw response = #{raw.strip}")

    # Try to extract VIN-like string
    vin = raw.strip.upcase.gsub(/[^A-HJ-NPR-Z0-9]/, "")
    if vin.length >= 16
      vin = vin[0..16]  # truncate to 17 chars
      Rails.logger.info("VinVisionService: extracted VIN = #{vin}")
      vin
    else
      Rails.logger.info("VinVisionService: no VIN found in '#{raw.strip}'")
      nil
    end
  rescue => e
    Rails.logger.error("VinVisionService error: #{e.message}")
    nil
  end
end
