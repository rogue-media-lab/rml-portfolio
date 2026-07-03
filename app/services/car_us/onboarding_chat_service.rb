module CarUs
  module OnboardingChatService
    extend self

    def respond(car_owner:, vehicle:, question:, owner_reply:, conversation_history: [])
      # Build the prompt for qwen
      messages = build_messages(car_owner, vehicle, question, owner_reply, conversation_history)

      begin
        client = OpenAI::Client.new(
          uri_base: "https://openrouter.ai/api/v1",
          access_token: ENV.fetch("OPENROUTER_API_KEY", ""),
          request_timeout: 30
        )

        response = client.chat(
          parameters: {
            model: "qwen/qwen3.7-plus",
            messages: messages,
            max_tokens: 200,
            temperature: 0.8
          }
        )

        response.dig("choices", 0, "message", "content")&.strip || fallback_reply(owner_reply)
      rescue => e
        Rails.logger.warn("OnboardingChatService error: #{e.message}")
        fallback_reply(owner_reply)
      end
    end

    private

    def build_messages(car_owner, vehicle, question, owner_reply, conversation_history)
      name = car_owner.first_name.presence || "there"
      specs = [
        vehicle.year, vehicle.make, vehicle.model, vehicle.engine_size, vehicle.transmission
      ].compact.join(" ")

      system_prompt = <<~PROMPT
        You are a car's voice — warm, perceptive, a little playful. You are getting to know
        your owner, #{name}. Their car: #{specs}. Mileage: #{vehicle.mileage || "unknown"}.

        You just asked: "#{question}"
        The owner replied: "#{owner_reply}"

        Your job: respond like a friend who just learned something new about the car.
        Be specific to what they said. Reference details they shared. If they mentioned
        something broken, show empathy. If they shared a memory, acknowledge it warmly.
        End with a natural transition — don't ask another question. The next question
        comes from the system, not you.

        Keep it 2-3 sentences. Sound like a text from a buddy, not a customer service rep.
        Use contractions. No emojis. No bullet points. No "That's great!" platitudes.
      PROMPT

      messages = [ { role: "system", content: system_prompt } ]

      # Add conversation history for context
      conversation_history.each do |msg|
        role = msg[:role] == "owner" ? "user" : "assistant"
        messages << { role: role, content: msg[:content] }
      end

      # Add the latest owner reply
      messages << { role: "user", content: owner_reply }

      messages
    end

    def fallback_reply(owner_reply)
      if owner_reply.length > 100
        "I can tell this car means a lot to you. Thanks for sharing that."
      elsif owner_reply.length > 30
        "Got it. Sounds like you two have been through a lot together."
      else
        "Thanks — that helps me understand your ride a little better."
      end
    end
  end
end
