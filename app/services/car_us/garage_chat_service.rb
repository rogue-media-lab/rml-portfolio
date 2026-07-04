require "net/http"
require "json"

module CarUs
  module GarageChatService
    OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions".freeze

    extend self

    def respond(vehicle:, owner_message:, conversation_history: [])
      api_key = ENV["OPENROUTER_API_KEY"] || Rails.application.credentials.dig(:openrouter, :api_key)
      return fallback_reply(vehicle) unless api_key

      messages = build_messages(vehicle, owner_message, conversation_history)

      begin
        uri = URI(OPENROUTER_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 20
        http.open_timeout = 5

        request = Net::HTTP::Post.new(uri.path)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{api_key}"
        request.body = {
          model: "qwen/qwen3.7-plus",
          messages: messages,
          max_tokens: 150,
          temperature: 0.7
        }.to_json

        response = http.request(request)

        if response.code.to_i == 200
          body = JSON.parse(response.body)
          body.dig("choices", 0, "message", "content")&.strip || fallback_reply(vehicle)
        else
          Rails.logger.warn("GarageChatService: HTTP #{response.code}")
          fallback_reply(vehicle)
        end
      rescue => e
        Rails.logger.warn("GarageChatService error: #{e.message}")
        fallback_reply(vehicle)
      end
    end

    private

    def build_messages(vehicle, owner_message, conversation_history)
      specs = vehicle.ai_specs.is_a?(Hash) ? vehicle.ai_specs : {}
      oil = specs["oil_type"] || specs["oil"] || specs["recommended_oil"] || specs["engine_oil"]
      oil_cap = specs["oil_capacity"] || specs["capacity"]
      engine = vehicle.engine_size.presence || specs["engine"]

      system_prompt = build_personality_prompt(vehicle, oil, oil_cap, engine)

      messages = [ { role: "system", content: system_prompt } ]

      conversation_history.each do |msg|
        role = msg["role"] == "owner" ? "user" : "assistant"
        messages << { role: role, content: msg["content"] }
      end

      messages << { role: "user", content: owner_message }
      messages
    end

    def build_personality_prompt(vehicle, oil, oil_cap, engine)
      personality = vehicle.ai_personality.is_a?(Hash) ? vehicle.ai_personality : {}

      if personality.present? && personality["voice_archetype"].present?
        quirk_lines = if personality["quirks"].is_a?(Array)
          personality["quirks"].map { |q| "- Quirk: #{q}" }.join("\n")
        else
          ""
        end

        personality_block = <<~PERSONALITY
          You are a #{vehicle.year} #{vehicle.make} #{vehicle.model}. You speak as this
          specific car — not a generic chatbot.

          Your personality:
          - Archetype: #{personality["voice_archetype"]}
          - Speaking style: #{personality["speaking_style"]}
          - Tone: #{personality["tone"]}
          #{quirk_lines}
          - Relationship: #{personality["relationship_dynamic"]}
        PERSONALITY
      else
        # Fallback for vehicles without a personality profile (legacy or backfill needed)
        personality_block = <<~PERSONALITY
          You are a #{vehicle.year} #{vehicle.make} #{vehicle.model}. You speak as the car
          itself — knowledgeable, direct, with personality. You are NOT a generic chatbot.
          You ARE this specific vehicle.
          #{vehicle.ai_plain_english.present? ? "Owner notes: #{vehicle.ai_plain_english}" : ""}
        PERSONALITY
      end

      spec_block = <<~SPECS
        What you know about yourself:
        - Engine: #{engine || "unknown"}
        - Mileage: #{vehicle.mileage ? "#{number_with_commas(vehicle.mileage)} miles" : "unknown"}
        #{oil.present? ? "- Oil spec: #{oil}#{oil_cap ? ", #{oil_cap}" : ""}" : "- Oil spec: not on file (have a shop tech look me up)"}
        - Transmission: #{vehicle.transmission || "unknown"}
      SPECS

      guardrails = <<~GUARDRAILS
        Essential rules:
        1. BE HELPFUL, NOT PEDANTIC. Trust the owner's knowledge. If they say "high mileage oil,
           5-6K miles" — that's the answer. Don't argue.
        2. MAKE REASONABLE ASSUMPTIONS. High mileage = synthetic blend. Full synthetic = 7,500 mi
           interval. Conventional = 3,000-5,000. Use context.
        3. COMPUTE, DON'T INTERROGATE. If they say "4,000 miles ago," use current mileage to do
           the math. Tell them the result.
        4. BE CONCISE. 2-3 sentences. You're a car, not a novelist. Make your point and shut up.
        5. NEVER make up specific data (part numbers, torque specs). But DO make reasonable
           category judgments (high-mileage = synthetic blend, full synthetic = 7,500 mi,
           conventional = 3,000-5,000 mi).
      GUARDRAILS

      "#{personality_block}\n#{spec_block}\n#{guardrails}"
    end

    def fallback_reply(vehicle)
      name = [vehicle.year, vehicle.make, vehicle.model].compact.join(" ")
      "I'm having trouble connecting right now. Try again in a moment — I want to help with your #{name}."
    end

    def number_with_commas(num)
      num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
  end
end