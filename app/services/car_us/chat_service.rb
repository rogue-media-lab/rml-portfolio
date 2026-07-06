# AI chat service — responds to tech messages in a conversation thread.
# Each call includes the full conversation history + vehicle context.
# When a photo is provided, includes it as vision input for VIN extraction.
#
class CarUs::ChatService
  OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
  MODEL = "qwen/qwen3.5-plus-02-15"

  def initialize(conversation)
    @conversation = conversation
  end

  # photo: raw ActionDispatch::Http::UploadedFile (optional — for vision/VIN extraction)
  def respond_to(message, photo: nil)
    api_key = ENV["OPENROUTER_API_KEY"] || Rails.application.credentials.dig(:openrouter, :api_key)

    # Quick return: if vehicle already linked with specs AND this is the first
    # message (no assistant responses yet), respond from cache. For follow-ups,
    # let the AI handle context-aware responses with labor times.
    if @conversation.vehicle&.ai_specs.present? && photo.nil?
      assistant_count = @conversation.messages.where(role: "assistant").count
      if assistant_count == 0
        specs = JSON.parse(@conversation.vehicle.ai_specs) rescue {}
        return cached_vehicle_response(message, specs)
      end
    end

    return fallback_response unless api_key

    # Build message history
    history = @conversation.messages.order(:created_at).map do |msg|
      { role: msg.role == "tech" ? "user" : "assistant", content: msg.content }
    end

    # System prompt with vehicle context
    system_prompt = {
      role: "system",
      content: build_system_prompt
    }

    # Current message — may include photo for vision
    current_message = build_current_message(message, photo)

    body = {
      model: MODEL,
      messages: [ system_prompt ] + history[0...-1] + [ current_message ],
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

    unless response.code.to_i == 200
      Rails.logger.error("ChatService: API returned #{response.code} — #{response.body[0..300]}")
      return fallback_response
    end

    data = JSON.parse(response.body)
    data.dig("choices", 0, "message", "content")&.strip || fallback_response
  rescue => e
    Rails.logger.error("ChatService error: #{e.message}")
    fallback_response
  end

  private

  def build_system_prompt
    v = @conversation.vehicle
    vehicle_context = if v
      parts = []
      parts << "#{v.year} #{v.make} #{v.model}"
      parts << "Engine: #{v.engine_size}" if v.engine_size.present?
      parts << "Transmission: #{v.transmission}" if v.transmission.present?
      parts << "Mileage: #{v.mileage}" if v.mileage.present?
      parts << "VIN: #{v.vin}" if v.vin.present?
      if v.ai_specs.present?
        begin
          specs = JSON.parse(v.ai_specs)
          parts << "Known specs: #{specs.map { |k, v2| "#{k}: #{v2}" }.join(', ')}" if specs.any?
        rescue
        end
      end
      parts.join(" | ")
    else
      "No vehicle linked yet."
    end

    <<~PROMPT
      You are an automotive technician assistant. You help techs look up specs, identify vehicles, suggest services, and answer questions. Be concise and practical — no fluff.

      Current vehicle context:
      #{vehicle_context}

      If the tech sends a photo of a vehicle or VIN plate, extract the VIN precisely and identify the vehicle (year, make, model, engine) from the VIN itself — do NOT guess the model from the photo. Then provide relevant specs (oil weight, capacity, filter, torque specs, fluid types).
      If the tech asks about a specific service, include specs and labor time estimates.
      Keep responses short — 2-4 sentences unless listing specs.
      If you extract a VIN from a photo, respond with: "VIN: [VIN] | [Year] [Make] [Model] | Engine: [size]" followed by key specs.
    PROMPT
  end

  def build_current_message(message, photo)
    if photo.present?
      begin
        photo.rewind  # reset in case ActiveStorage already read it

        # Resize before encoding — raw phone photos are 3-4MB, too large
        # for API payloads. Max 1024px on longest side, JPEG quality 80.
        resized = resize_for_vision(photo)
        base64_image = Base64.strict_encode64(resized)
        mime = "image/jpeg"
        data_url = "data:#{mime};base64,#{base64_image}"

        Rails.logger.info("ChatService: photo encoded — #{resized.bytesize} bytes (was #{photo.size} bytes)")

        text = message.content.presence || "What vehicle is this? Extract the VIN and provide specs."

        {
          role: "user",
          content: [
            { type: "text", text: text },
            { type: "image_url", image_url: { url: data_url } }
          ]
        }
      rescue => e
        Rails.logger.error("ChatService: failed to encode photo — #{e.message}")
        { role: "user", content: message.content }
      end
    else
      { role: "user", content: message.content }
    end
  end

  # Resize image for vision API — cap at 1024px longest edge, JPEG quality 80.
  # Reduces 3-4MB phone photos to ~100-200KB without losing VIN legibility.
  def resize_for_vision(photo)
    require "mini_magick"

    path = if photo.respond_to?(:tempfile)
             photo.tempfile.path
    elsif photo.respond_to?(:path)
             photo.path
    else
             photo.to_s
    end

    image = MiniMagick::Image.open(path)
    image.resize "1024x1024>"
    image.format "jpeg"
    image.quality "80"
    image.to_blob
  end

  def fallback_response
    v = @conversation.vehicle
    if v&.ai_specs.present?
      "I have the specs for this #{v.year} #{v.make} #{v.model} on file. What would you like to know?"
    elsif v
      "I have this #{v.year} #{v.make} #{v.model} on file. What service are we doing today?"
    else
      "I'm ready. Send me a photo of the VIN plate or type the VIN to get started."
    end
  end

  def cached_vehicle_response(message, specs)
    v = @conversation.vehicle
    lines = []
    lines << "**#{v.year} #{v.make} #{v.model}** — specs on file."
    if specs["oil_weight"].present?
      lines << "Oil: #{specs["oil_weight"]} | #{specs["oil_capacity_qts"]} qts | Filter: #{specs["oil_filter"]}"
    end
    lines << "Torque: #{specs["drain_plug_torque_ft_lbs"]} ft-lbs" if specs["drain_plug_torque_ft_lbs"].present?
    lines << "Cabin filter: #{specs["cabin_air_filter"]}" if specs["cabin_air_filter"].present?
    lines << "Engine filter: #{specs["engine_air_filter"]}" if specs["engine_air_filter"].present?
    lines << "Tires: #{specs["tire_pressure_f"]}F / #{specs["tire_pressure_r"]}R" if specs["tire_pressure_f"].present?
    lines << ""
    lines << "What service are we doing? I'll give you labor times."
    lines.join("\n")
  end
end
