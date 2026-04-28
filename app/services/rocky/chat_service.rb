# frozen_string_literal: true

module Rocky
  class ChatService
    def initialize(messages:)
      @messages = messages
      @client = OpenAI::Client.new(
        access_token: Rails.application.credentials.dig(:openrouter, :api_key),
        uri_base: "https://openrouter.ai/api/v1"
      )
    end

    # Stream Rocky's response via SSE.
    # Yields content chunks to the block.
    # Returns the full assistant text when done.
    def stream(&block)
      full_text = ""

      # Prepend system prompt as first message
      all_messages = [{ role: "system", content: system_prompt_with_tones }] + @messages

      @client.chat(
        parameters: {
          model: ROCKY_MODEL,
          max_tokens: ROCKY_MAX_TOKENS,
          messages: all_messages,
          stream: proc do |chunk, _bytesize|
            delta = chunk.dig("choices", 0, "delta", "content")
            if delta
              full_text += delta
              block.call({ type: "content", delta: delta })
            end
          end
        }
      )

      block.call({ type: "done" })
      full_text
    rescue StandardError => e
      Rails.logger.error("Rocky chat error: #{e.message}")
      block.call({ type: "error", message: "Rocky is having trouble. Try again." })
      ""
    end

    private

    def system_prompt_with_tones
      tone_index_path = Rails.root.join("public", "tones", "tone_index.json")
      return ROCKY_SYSTEM_PROMPT unless File.exist?(tone_index_path)

      descriptions = JSON.parse(File.read(tone_index_path)).keys.sort
      return ROCKY_SYSTEM_PROMPT if descriptions.empty?

      vocab = descriptions.map { |d| "- #{d}" }.join("\n")
      ROCKY_SYSTEM_PROMPT + <<~ADDENDUM

        Your tone vocabulary — use ONLY these descriptions, copied word for word:
        #{vocab}

        Do not invent tone descriptions. Pick the closest match from the list above.
      ADDENDUM
    end
  end
end
