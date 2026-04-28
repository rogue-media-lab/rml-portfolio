# frozen_string_literal: true

module Rocky
  class TtsService
    class Error < StandardError; end

    ELEVENLABS_VOICE_ID = "vBKc2FfBKJfcZNyEt1n6" # Finn
    ELEVENLABS_URL      = "https://api.elevenlabs.io/v1/text-to-speech"

    def initialize(text:)
      @text = text
      @api_key = Rails.application.credentials.dig(:eleven_labs, :api_key)
    end

    # Returns { audio_data: String (binary), content_type: String }
    def call
      uri = URI("#{ELEVENLABS_URL}/#{ELEVENLABS_VOICE_ID}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request["xi-api-key"] = @api_key
      request["Content-Type"] = "application/json"
      request["Accept"] = "audio/mpeg"
      request.body = {
        text: @text,
        model_id: "eleven_monolingual_v1",
        voice_settings: {
          stability: 0.6,
          similarity_boost: 0.75
        }
      }.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("ElevenLabs TTS error: #{response.code} #{response.body}")
        raise Error, "TTS unavailable (#{response.code})"
      end

      { audio_data: response.body, content_type: "audio/mpeg" }
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("ElevenLabs TTS timeout: #{e.message}")
      raise Error, "TTS timeout"
    end
  end
end
