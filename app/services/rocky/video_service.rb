# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Rocky
  class VideoService
    SUBMIT_URL = "https://api.minimax.io/v1/video_generation"
    STATUS_URL = "https://api.minimax.io/v1/query/video_generation"

    def initialize(prompt: nil, api_key: nil)
      @prompt  = prompt
      @api_key = api_key || Rails.application.credentials.dig(:minimax, :api_key)
    end

    # Submit a job and return the task_id immediately (does not poll).
    # Returns task_id string.
    # Raises Rocky::VideoService::Error on failure.
    def submit
      raise Error, "prompt is required for submit" if @prompt.blank?
      raise Error, "MiniMax API key is not configured" if @api_key.blank?

      submit_job
    rescue Error
      raise
    rescue StandardError => e
      raise Error, "Video submit failed: #{e.message}"
    end

    # Poll an existing task_id until complete or timeout.
    # Returns { url: "https://...", task_id: "..." }
    # Raises Rocky::VideoService::Error on failure or timeout.
    def poll(task_id, max_attempts: 20, interval: 10)
      raise Error, "MiniMax API key is not configured" if @api_key.blank?

      poll_for_completion(task_id, max_attempts: max_attempts, interval: interval)
    rescue Error
      raise
    rescue StandardError => e
      raise Error, "Video poll failed: #{e.message}"
    end

    # Legacy: submit + poll in one call (kept for slash-command path and tests).
    # Returns { url: "https://...", task_id: "..." }
    def call
      raise Error, "MiniMax API key is not configured" if @api_key.blank?

      task_id = submit_job
      poll_for_completion(task_id, max_attempts: 20, interval: 10)
    rescue Error
      raise
    rescue StandardError => e
      raise Error, "Video generation failed: #{e.message}"
    end

    class Error < StandardError; end

    private

    def submit_job
      uri  = URI.parse(SUBMIT_URL)
      body = {
        model:  "T2V-01-Director",
        prompt: @prompt
      }.to_json

      response = post_json(uri, body)

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "MiniMax submit returned #{response.code}: #{response.body}"
      end

      parsed  = JSON.parse(response.body)
      task_id = parsed["task_id"] || parsed.dig("data", "task_id")

      raise Error, "No task_id in MiniMax submit response: #{response.body}" if task_id.nil?

      task_id
    end

    def poll_for_completion(task_id, max_attempts: 24, interval: 5)
      max_attempts.times do |attempt|
        sleep(interval) if attempt > 0

        status_data = fetch_status(task_id)
        status      = status_data["status"] || status_data.dig("data", "status") || ""

        case status.downcase
        when "success", "finished", "completed"
          url = extract_video_url(status_data)
          # MiniMax sometimes returns only file_id — fetch download URL from Files API
          if url.nil? && (file_id = status_data["file_id"] || status_data.dig("data", "file_id"))
            url = fetch_file_url(file_id)
          end
          raise Error, "Video succeeded but no URL found in response: #{status_data}" if url.nil?

          return { url: url, task_id: task_id }
        when "failed", "error"
          raise Error, "Video generation job #{task_id} failed: #{status_data.inspect}"
        end
        # Still processing — continue polling
      end

      raise Error, "Video generation timed out after #{max_attempts * interval} seconds (task_id: #{task_id})"
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
        raise Error, "MiniMax status check returned #{response.code}: #{response.body}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise Error, "Failed to parse MiniMax status response: #{e.message}"
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

    def extract_video_url(parsed)
      parsed.dig("data", "video_url") ||
        parsed.dig("output", "video_url") ||
        parsed["video_url"] ||
        parsed.dig("data", "file_url") ||
        parsed["file_url"]
    end

    # When the status response has a file_id but no URL, call the Files API to get the download URL
    def fetch_file_url(file_id)
      uri = URI.parse("https://api.minimax.io/v1/files/retrieve?file_id=#{URI.encode_uri_component(file_id)}")

      http          = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl  = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri.request_uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"]  = "application/json"

      response = http.request(request)

      return nil unless response.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(response.body)
      parsed.dig("file", "download_url") || parsed["download_url"]
    rescue StandardError => e
      Rails.logger.error("Rocky VideoService: file URL fetch failed for #{file_id}: #{e.message}")
      nil
    end
  end
end
