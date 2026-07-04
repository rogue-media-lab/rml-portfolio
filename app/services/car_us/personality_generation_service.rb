require "net/http"
require "json"

module CarUs
  module PersonalityGenerationService
    OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions".freeze

    extend self

    # onboarding_messages: Array of { "role" => "owner"/"assistant", "content" => "..." }
    def call(vehicle:, onboarding_messages:)
      api_key = ENV["OPENROUTER_API_KEY"] || Rails.application.credentials.dig(:openrouter, :api_key)
      return nil unless api_key
      return nil if onboarding_messages.blank?

      messages = build_generation_prompt(vehicle, onboarding_messages)

      begin
        uri = URI(OPENROUTER_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 30
        http.open_timeout = 5

        request = Net::HTTP::Post.new(uri.path)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{api_key}"
        request.body = {
          model: "qwen/qwen3.7-plus",
          messages: messages,
          max_tokens: 300,
          temperature: 0.7,
          response_format: { type: "json_object" }
        }.to_json

        response = http.request(request)

        if response.code.to_i == 200
          body = JSON.parse(response.body)
          raw = body.dig("choices", 0, "message", "content")
          return nil unless raw

          personality = JSON.parse(raw)
          personality["generated_at"] = Time.current.iso8601
          personality
        else
          Rails.logger.warn("PersonalityGenerationService: HTTP #{response.code}")
          nil
        end
      rescue => e
        Rails.logger.warn("PersonalityGenerationService error: #{e.message}")
        nil
      end
    end

    private

    def build_generation_prompt(vehicle, messages)
      # Extract the conversation as readable text
      transcript = messages.map do |m|
        role = m["role"] == "owner" ? vehicle.car_owner&.first_name || "Owner" : "Car"
        "#{role}: #{m["content"]}"
      end.join("\n\n")

      specs = [
        vehicle.year, vehicle.make, vehicle.model,
        vehicle.engine_size, vehicle.transmission
      ].compact.join(" ")

      system_prompt = <<~PROMPT
        You are a personality analyst for cars. You read a conversation between a car
        owner and their vehicle's AI voice (which spoke as the car itself during onboarding).

        Vehicle: #{specs}
        Mileage: #{vehicle.mileage || "unknown"}

        Here is their onboarding conversation:

        #{transcript}

        Analyze this conversation and generate a personality profile for this specific
        vehicle. The personality should reflect what the owner shared — their driving
        patterns, the car's condition, the emotional relationship, and how the owner
        described the car's voice.

        Return a JSON object with these fields:
        - voice_archetype: one of "loyal_old_dog", "workhorse", "garage_queen", "family_hauler", "new_tech_friend" (infer this, don't ask)
        - speaking_style: 1-2 sentences describing HOW this car talks. Be specific and concrete.
          NOT "friendly and helpful" — instead "Calls out creaks by name. Asks if you felt that too.
          Proud of the dash. Uses 'we' not 'I'."
        - tone: one of "practical_weathered", "polished_enthusiast", "warm_family", "efficient_data", "quiet_loyal"
        - quirks: array of 1-3 specific behavioral quirks this car would have, based on the conversation.
          E.g. "Mentions the dash condition unprompted", "Compares itself to other cars the owner knew",
          "Always asks about the kids before discussing maintenance"
        - relationship_dynamic: 1 sentence describing the relationship between this owner and car.
          E.g. "Partnership. 34 years. The owner shifts, the car goes. No drama."

        Rules:
        - NEVER say "unknown" or "not specified". If a detail isn't in the conversation, omit it.
        - Be specific. "Loyal old dog who's proud of surviving longer than Jimmy's Civic" > "old car".
        - The quirks must be unique to THIS car, not generic. They should reference details from the conversation.
        - Output ONLY valid JSON. No markdown, no explanation, no wrapping.
      PROMPT

      [
        { role: "system", content: system_prompt },
        { role: "user", content: "Generate the personality profile JSON for this vehicle." }
      ]
    end
  end
end