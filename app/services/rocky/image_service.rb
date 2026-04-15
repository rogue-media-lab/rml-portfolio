# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Rocky
  class ImageService
    API_URL = "https://api.minimax.io/v1/image_generation"

    def initialize(prompt:)
      @prompt  = prompt
      @api_key = Rails.application.credentials.dig(:minimax, :api_key)
    end

    # Returns { url: "https://...", prompt: @prompt }
    # Raises Rocky::ImageService::Error on failure
    def call
      raise Error, "MiniMax API key is not configured" if @api_key.blank?

      uri  = URI.parse(API_URL)
      body = {
        model:        "image-01",
        prompt:       @prompt,
        n:            1,
        aspect_ratio: "16:9"
      }.to_json

      http          = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl  = true
      http.open_timeout = 10
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"]  = "application/json"
      request.body             = body

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "MiniMax API returned #{response.code}: #{response.body}"
      end

      parsed = JSON.parse(response.body)
      url    = extract_image_url(parsed)

      raise Error, "No image URL in MiniMax response: #{response.body}" if url.nil?

      { url: url, prompt: @prompt }
    rescue Error
      raise
    rescue JSON::ParserError => e
      raise Error, "Failed to parse MiniMax response: #{e.message}"
    rescue StandardError => e
      raise Error, "Image generation failed: #{e.message}"
    end

    class Error < StandardError; end

    private

    def extract_image_url(parsed)
      # Support multiple MiniMax response shapes
      parsed.dig("data", "image_urls", 0) ||
        parsed.dig("data", "images", 0, "url") ||
        parsed.dig("output", "image_urls", 0) ||
        parsed.dig("image_urls", 0)
    end
  end
end
