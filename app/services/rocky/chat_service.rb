# frozen_string_literal: true

module Rocky
  class ChatService
    TOOLS = [
      {
        name: "generate_image",
        description: "Generate an image to show the user. Use when asked to visualize something, " \
                     "show a place, creature, or concept from Project Hail Mary or space science. " \
                     "Rocky uses this naturally when showing would help more than telling.",
        input_schema: {
          type: "object",
          properties: {
            prompt: {
              type: "string",
              description: "Detailed visual description. Include style, lighting, subject, and setting."
            }
          },
          required: ["prompt"]
        }
      },
      {
        name: "generate_video",
        description: "Generate a short video clip. Use when motion, orbit, process, or animation " \
                     "would better explain a concept than a still image.",
        input_schema: {
          type: "object",
          properties: {
            prompt: {
              type: "string",
              description: "Description of the video content and any motion or animation."
            }
          },
          required: ["prompt"]
        }
      },
      {
        name: "generate_music",
        description: "Generate ambient music or sound. Use when the user wants to hear something " \
                     "or requests atmospheric audio — like the sound of deep space or an Eridian ship.",
        input_schema: {
          type: "object",
          properties: {
            prompt: {
              type: "string",
              description: "Description of the music style, mood, instruments, and atmosphere."
            }
          },
          required: ["prompt"]
        }
      }
    ].freeze

    def initialize(messages:)
      @messages = messages
      @client   = Anthropic::Client.new(
        api_key: Rails.application.credentials.dig(:anthropic, :api_key)
      )
    end

    # Phase 1: stream Rocky's initial response.
    # Yields content/tool_call/phase_done chunks.
    # Returns array of tool_call hashes for the controller to execute.
    def stream(&block)
      input_tokens  = 0
      output_tokens = 0
      tool_building = {}  # content_block index => { id:, name:, input_json: }

      message_stream = @client.messages.stream(
        model:      ROCKY_MODEL,
        max_tokens: ROCKY_MAX_TOKENS,
        system_:    system_prompt_with_tones,
        tools:      TOOLS,
        messages:   @messages
      )

      message_stream.each do |event|
        case event.type
        when :message_start
          input_tokens = event.message.usage.input_tokens.to_i

        when :content_block_start
          if event.content_block.type == :tool_use
            tool_building[event.index] = {
              id:         event.content_block.id,
              name:       event.content_block.name,
              input_json: ""
            }
          end

        when :content_block_delta
          case event.delta.type
          when :text_delta
            block.call({ type: "content", delta: event.delta.text })
          when :input_json_delta
            tool_building[event.index][:input_json] += event.delta.partial_json if tool_building[event.index]
          end

        when :message_delta
          output_tokens = event.usage.output_tokens.to_i
        end
      end

      # Parse and emit completed tool calls
      tool_calls = tool_building.values.map do |tc|
        tc.merge(input: JSON.parse(tc[:input_json]))
      rescue JSON::ParserError
        tc.merge(input: {})
      end

      tool_calls.each do |tc|
        block.call({ type: "tool_call", tool: tc[:name], tool_use_id: tc[:id], input: tc[:input] })
      end

      cost = calculate_cost(input_tokens, output_tokens)
      block.call({ type: "phase_done", input_tokens:, output_tokens:, cost_usd: cost })

      tool_calls
    rescue Anthropic::Errors::APIError => e
      raise Error, "Anthropic API error: #{e.message}"
    rescue StandardError => e
      raise Error, "Chat stream failed: #{e.message}"
    end

    # Phase 2: continue after tool execution.
    # messages should include the full conversation + assistant tool_use + tool_results.
    # Yields content/done chunks.
    def stream_continuation(messages:, &block)
      input_tokens  = 0
      output_tokens = 0

      message_stream = @client.messages.stream(
        model:      ROCKY_MODEL,
        max_tokens: ROCKY_MAX_TOKENS,
        system_:    system_prompt_with_tones,
        tools:      TOOLS,
        messages:   messages
      )

      message_stream.each do |event|
        case event.type
        when :message_start
          input_tokens = event.message.usage.input_tokens.to_i
        when :content_block_delta
          block.call({ type: "content", delta: event.delta.text }) if event.delta.type == :text_delta
        when :message_delta
          output_tokens = event.usage.output_tokens.to_i
        end
      end

      cost = calculate_cost(input_tokens, output_tokens)
      block.call({ type: "done", input_tokens:, output_tokens:, cost_usd: cost })
    rescue Anthropic::Errors::APIError => e
      raise Error, "Anthropic API error (continuation): #{e.message}"
    rescue StandardError => e
      raise Error, "Chat continuation failed: #{e.message}"
    end

    class Error < StandardError; end

    private

    def system_prompt_with_tones
      descriptions = Tone.where.not(description: nil).pluck(:description).sort
      return ROCKY_SYSTEM_PROMPT if descriptions.empty?

      vocab = descriptions.map { |d| "- #{d}" }.join("\n")
      ROCKY_SYSTEM_PROMPT + <<~ADDENDUM

        Your tone vocabulary — use ONLY these descriptions, copied word for word:
        #{vocab}

        Do not invent tone descriptions. Pick the closest match from the list above.
      ADDENDUM
    end

    def calculate_cost(input_tokens, output_tokens)
      # Claude Haiku pricing: $0.80/M input, $4.00/M output
      input_cost  = (input_tokens  / 1_000_000.0) * 0.80
      output_cost = (output_tokens / 1_000_000.0) * 4.00
      (input_cost + output_cost).round(8)
    end
  end
end
