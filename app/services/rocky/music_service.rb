# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Rocky
  class MusicService
    SUBMIT_URL = "https://api.minimax.io/v1/music_generation"
    STATUS_URL = "https://api.minimax.io/v1/query/music_generation"

    def initialize(prompt:)
      @prompt  = prompt
      @api_key = Rails.application.credentials.dig(:minimax, :api_key)
    end

    # Returns { url: "https://...", task_id: "..." }
    # Raises Rocky::MusicService::Error on failure or timeout
    def call
      raise Error, "MiniMax API key is not configured" if @api_key.blank?

      task_id = submit_job
      poll_for_completion(task_id)
    rescue Error
      raise
    rescue StandardError => e
      raise Error, "Music generation failed: #{e.message}"
    end

    class Error < StandardError; end

    private

    def submit_job
      uri  = URI.parse(SUBMIT_URL)
      body = {
        model:                  "music-01",
        lyrics_1:               @prompt,
        refer_instrumental_1:   ""
      }.to_json

      response = post_json(uri, body)

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "MiniMax submit returned #{response.code}: #{response.body}"
      end

      parsed  = JSON.parse(response.body)
      task_id = parsed["task_id"] || parsed.dig("data", "task_id")

      raise Error, "No task_id in MiniMax music submit response: #{response.body}" if task_id.nil?

      task_id
    end

    def poll_for_completion(task_id, max_attempts: 24, interval: 5)
      max_attempts.times do |attempt|
        sleep(interval) if attempt > 0

        status_data = fetch_status(task_id)
        status      = status_data["status"] || status_data.dig("data", "status") || ""

        case status.downcase
        when "success", "finished", "completed"
          url = extract_audio_url(status_data)
          raise Error, "Music succeeded but no URL found in response: #{status_data}" if url.nil?

          return { url: url, task_id: task_id }
        when "failed", "error"
          raise Error, "Music generation job #{task_id} failed: #{status_data.inspect}"
        end
        # Still processing — continue polling
      end

      raise Error, "Music generation timed out after #{max_attempts * interval} seconds (task_id: #{task_id})"
    end

    def fetch_status(task_id)
      uri = URI.parse("#{STATUS_URL}?task_id=#{URI.encode_uri_component(task_id)}")

      http          = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl  = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri.request_uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"]  = "application/json"

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "MiniMax music status returned #{response.code}: #{response.body}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise Error, "Failed to parse MiniMax music status response: #{e.message}"
    end

    def post_json(uri, body)
      http          = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl  = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"]  = "application/json"
      request.body             = body

      http.request(request)
    end

    def extract_audio_url(parsed)
      parsed.dig("data", "audio_url") ||
        parsed.dig("output", "audio_url") ||
        parsed["audio_url"] ||
        parsed.dig("data", "file_url") ||
        parsed["file_url"]
    end
  end
end
