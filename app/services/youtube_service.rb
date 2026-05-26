require "net/http"
require "json"
require "uri"

class YoutubeService
  API_KEY = ENV["YOUTUBE_API_KEY"]
  BASE_URL = "https://www.googleapis.com/youtube/v3"

  class Error < StandardError; end
  class QuotaExceeded < Error; end
  class InvalidKey < Error; end

  # --- PUBLIC API ---

  # Search for recent uploads from a channel
  # Returns array of video hashes:
  #   { video_id:, title:, description:, thumbnail_url:, published_at: }
  def self.search_channel_videos(channel_id, max_results: 50)
    return [] if API_KEY.blank?

    params = {
      "part"       => "snippet",
      "channelId"  => channel_id,
      "maxResults" => max_results,
      "order"      => "date",
      "type"       => "video",
      "key"        => API_KEY
    }

    response = get("/search", params)
    items = response["items"] || []

    items.map do |item|
      snippet = item["snippet"]
      {
        video_id:      item.dig("id", "videoId"),
        title:         snippet["title"],
        description:   snippet["description"],
        thumbnail_url: best_thumbnail(snippet["thumbnails"]),
        published_at:  snippet["publishedAt"]
      }
    end.compact
  end

  # Batch fetch video details (duration, stats, etc.)
  # video_ids: array of YouTube video IDs
  # Returns array of hashes keyed by video_id
  def self.video_details(video_ids)
    return {} if API_KEY.blank? || video_ids.empty?

    # API limit: 50 IDs per call
    results = {}
    video_ids.each_slice(50) do |batch|
      params = {
        "part" => "snippet,contentDetails,statistics",
        "id"   => batch.join(","),
        "key"  => API_KEY
      }

      response = get("/videos", params)
      (response["items"] || []).each do |item|
        vid = item["id"]
        snippet = item["snippet"]
        results[vid] = {
          video_id:       vid,
          title:          snippet["title"],
          description:    snippet["description"],
          thumbnail_url:  best_thumbnail(snippet["thumbnails"]),
          published_at:   snippet["publishedAt"],
          duration:       item.dig("contentDetails", "duration"),
          view_count:     item.dig("statistics", "viewCount"),
          like_count:     item.dig("statistics", "likeCount"),
          channel_id:     snippet["channelId"],
          channel_title:  snippet["channelTitle"]
        }
      end
    end

    results
  end

  # Resolve a YouTube channel URL or handle to a channel ID
  # Accepts: @handle, channel/UC..., user/username, c/channelname, or full URLs
  def self.resolve_channel_id(input)
    return nil if API_KEY.blank? || input.blank?

    # Already a channel ID
    return input if input.start_with?("UC") && input.length == 24

    # Extract from a full URL
    uri = URI.parse(input)
    path = uri.path.to_s

    if path.start_with?("/channel/")
      return path.split("/").last
    elsif path.start_with?("/c/", "/user/")
      # Need to search by forUsername or custom URL
      handle = path.split("/").last
      return search_channel_by_handle(handle)
    elsif path.start_with?("/@")
      handle = path[2..].split("/").first
      return search_channel_by_handle("@#{handle}")
    end

    # Bare @handle or channel name
    if input.start_with?("@")
      search_channel_by_handle(input)
    else
      search_channel_by_handle("@#{input}")
    end
  rescue URI::InvalidURIError
    search_channel_by_handle(input)
  end

  # Search for a channel by handle or name, return first matching channel ID
  def self.search_channel_by_handle(handle)
    return nil if API_KEY.blank?

    params = {
      "part"      => "snippet",
      "q"         => handle,
      "type"      => "channel",
      "maxResults"=> 1,
      "key"       => API_KEY
    }

    response = get("/search", params)
    item = response.dig("items", 0)
    item&.dig("id", "channelId")
  end

  # Validate that a thumbnail URL still returns HTTP 200
  def self.validate_thumbnail_url(url)
    return false if url.blank?

    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 5

    request = Net::HTTP::Head.new(uri.request_uri)
    response = http.request(request)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    false
  end

  # Extract video ID from a YouTube URL
  def self.extract_video_id(url)
    return nil if url.blank?

    patterns = [
      %r{youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})},
      %r{youtu\.be/([a-zA-Z0-9_-]{11})},
      %r{youtube\.com/embed/([a-zA-Z0-9_-]{11})},
      %r{youtube\.com/v/([a-zA-Z0-9_-]{11})}
    ]

    patterns.each do |pattern|
      match = url.match(pattern)
      return match[1] if match
    end

    nil
  end

  # --- PRIVATE ---

  def self.get(endpoint, params)
    uri = URI.parse("#{BASE_URL}#{endpoint}")
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 15
    http.read_timeout = 15

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    handle_errors!(response)

    JSON.parse(response.body)
  end

  def self.handle_errors!(response)
    return if response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body) rescue {}
    error = body.dig("error", "errors", 0, "reason") || "unknown"
    message = body.dig("error", "message") || "YouTube API error"

    case error
    when "quotaExceeded"
      raise QuotaExceeded, message
    when "keyInvalid"
      raise InvalidKey, message
    else
      raise Error, "#{error}: #{message}"
    end
  rescue JSON::ParserError
    raise Error, "YouTube API returned non-JSON: #{response.code}"
  end

  # Pick the highest-resolution available thumbnail
  def self.best_thumbnail(thumbnails)
    return nil if thumbnails.blank?

    %w[maxres high medium standard default].each do |quality|
      return thumbnails.dig(quality, "url") if thumbnails[quality].present?
    end
    nil
  end
end
