# frozen_string_literal: true

module Rocky
  # Synthesizes speech via OpenAI's gpt-4o-mini-tts (pure Ruby HTTP — no
  # Python, no buildpack changes on Heroku). Drop-in replacement for the
  # prior ElevenLabs implementation; preserves the { audio_data:,
  # content_type: } contract so RockyController#tts and the front-end
  # audio pipeline need no changes.
  #
  # Voice / speed / model / instructions tunable via ROCKY_TTS_VOICE /
  # _SPEED / _MODEL / _INSTRUCTIONS. API key from ENV["OPENAI_API_KEY"]
  # or Rails credentials (:openai, :api_key).
  class TtsService
    class Error < StandardError; end

    OPENAI_URL = "https://api.openai.com/v1/audio/speech"
    TIMEOUT_SEC = 30

    DEFAULT_MODEL = "gpt-4o-mini-tts"
    DEFAULT_VOICE = "echo"
    DEFAULT_SPEED = 1.15
    DEFAULT_INSTRUCTIONS = <<~INST.freeze
      Speak with quick, curious, hummingbird energy — like an alien \
      engineer excitedly explaining physics to a friend. Short \
      sentences, upbeat, warm.
    INST

    def initialize(text:)
      @text         = text
      @api_key      = ENV["OPENAI_API_KEY"].presence ||
                      Rails.application.credentials.dig(:openai, :api_key)
      @model        = ENV.fetch("ROCKY_TTS_MODEL", DEFAULT_MODEL)
      @voice        = ENV.fetch("ROCKY_TTS_VOICE", DEFAULT_VOICE)
      @speed        = ENV.fetch("ROCKY_TTS_SPEED", DEFAULT_SPEED).to_f
      @instructions = ENV.fetch("ROCKY_TTS_INSTRUCTIONS", DEFAULT_INSTRUCTIONS)
    end

    # Returns { audio_data: String (binary), content_type: String }
    def call
      raise Error, "OPENAI_API_KEY missing (set ENV or credentials)" if @api_key.to_s.empty?

      uri  = URI(OPENAI_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.open_timeout = TIMEOUT_SEC
      http.read_timeout = TIMEOUT_SEC

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"]  = "application/json"
      request.body = {
        model:           @model,
        input:           @text,
        voice:           @voice,
        speed:           @speed,
        response_format: "mp3",
        instructions:    @instructions
      }.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("OpenAI TTS error: #{response.code} #{response.body.to_s[0, 500]}")
        raise Error, "TTS unavailable (#{response.code})"
      end

      { audio_data: response.body, content_type: "audio/mpeg" }
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("OpenAI TTS timeout: #{e.message}")
      raise Error, "TTS timeout"
    end
  end
end
