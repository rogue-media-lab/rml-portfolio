# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Rocky
  class TtsService
    VOICE_ID  = "vBKc2FfBKJfcZNyEt1n6" # Finn
    API_URL   = "https://api.elevenlabs.io/v1/text-to-speech/#{VOICE_ID}"
    MODEL_ID  = "eleven_flash_v2_5"

    def initialize(text:)
      @text    = sanitize_for_tts(text)
      @api_key = Rails.application.credentials.dig(:elevenlabs, :api_key)
    end

    # Returns { audio_data: binary_string, content_type: "audio/mpeg" }
    # Raises Rocky::TtsService::Error on failure
    def call
      raise Error, "ElevenLabs API key is not configured" if @api_key.blank?

      uri  = URI.parse(API_URL)
      body = {
        text:           @text,
        model_id:       MODEL_ID,
        voice_settings: {
          stability:        0.45,
          similarity_boost: 0.40,
          speed:            1.0
        }
      }.to_json

      http          = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl  = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.request_uri)
      request["xi-api-key"]   = @api_key
      request["Content-Type"] = "application/json"
      request["Accept"]       = "audio/mpeg"
      request.body            = body

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "ElevenLabs API returned #{response.code}: #{response.body}"
      end

      { audio_data: response.body.force_encoding("BINARY"), content_type: "audio/mpeg" }
    rescue Error
      raise
    rescue StandardError => e
      raise Error, "TTS request failed: #{e.message}"
    end

    class Error < StandardError; end

    private

    def sanitize_for_tts(text)
      text
        .gsub("—", ", ")        # em dash → spoken pause
        .gsub("–", ", ")        # en dash → spoken pause
        .gsub("…", "...")       # ellipsis char → ASCII dots (ElevenLabs handles these fine)
        .gsub("*", "")          # strip asterisks (markdown bold/italic remnants)
        .gsub(/[^\x00-\x7F]/) { |c| UNICODE_REPLACEMENTS.fetch(c, "") }
        .gsub(/  +/, " ")       # collapse multiple spaces
        .strip
    end

    # Punctuation chars outside ASCII that ElevenLabs may read phonetically
    UNICODE_REPLACEMENTS = {
      "\u2018" => "'",   # left single quotation mark
      "\u2019" => "'",   # right single quotation mark
      "\u201C" => '"',   # left double quotation mark
      "\u201D" => '"',   # right double quotation mark
      "\u2022" => "",    # bullet
      "\u00B7" => "",    # middle dot
      "\u2014" => ", ",  # em dash (belt-and-suspenders, in case gsub above misses encoding variant)
      "\u2013" => ", ",  # en dash
      "\u2026" => "...", # ellipsis
    }.freeze
  end
end
