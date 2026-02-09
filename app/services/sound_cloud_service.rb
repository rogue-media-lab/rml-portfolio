# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# Handles all communication with the SoundCloud API.
# Manages OAuth2 access and refresh tokens persistently.
class SoundCloudService
  BASE_URL = "https://api-v2.soundcloud.com"
  TOKEN_FILE = Rails.root.join("config", "soundcloud_token.json")
  CLIENT_ID = ENV["SOUNDCLOUD_CLIENT_ID"] || Rails.application.credentials.dig(:soundcloud, :client_id)
  CLIENT_SECRET = ENV["SOUNDCLOUD_CLIENT_SECRET"] || Rails.application.credentials.dig(:soundcloud, :client_secret)

  # Retrieves a valid access token, refreshing it if necessary.
  def self.access_token
    ensure_valid_token
  end

  # Searches for tracks on SoundCloud based on a query.
  def search(query)
    uri = URI("#{BASE_URL}/search/tracks")
    params = {
      q: query,
      limit: 10
    }
    uri.query = URI.encode_www_form(params)

    token = self.class.access_token
    headers = {}
    headers["Authorization"] = "OAuth #{token}" if token

    response = Net::HTTP.get_response(uri, headers)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)["collection"]
    else
      Rails.logger.error "SoundCloud API Error: #{response.code} #{response.message}"
      []
    end
  rescue JSON::ParserError => e
    Rails.logger.error "SoundCloud JSON Parse Error: #{e.message}"
    []
  end

  # Public V2 Client ID (Borrowed from Web Player to bypass preview restrictions)
  PUBLIC_V2_CLIENT_ID = "KKzJxmw11tYpCs6T24P4uUYhqmjalG6M"

  # Fetches a single track from the SoundCloud API.
  def get_track(track_id)
    token = self.class.access_token
    return nil unless token

    # Note: V1 tracks endpoint format is /tracks/:id
    uri = URI("https://api.soundcloud.com/tracks/#{track_id}")

    headers = { "Authorization" => "OAuth #{token}" }

    response = Net::HTTP.get_response(uri, headers)

    if response.is_a?(Net::HTTPSuccess)
      track = JSON.parse(response.body)

      # FALLBACK: If V1 returns no media object (likely preview only),
      # try to fetch full V2 stream data using the Public Client ID.
      if !track.key?("media")
        Rails.logger.info "SoundCloud: V1 track likely restricted. Attempting V2 resolve with Public ID..."
        v2_stream = resolve_v2_stream(track_id)
        if v2_stream
          track["stream_url"] = v2_stream
          # Add a flag so frontend knows this is a direct stream
          track["is_direct_stream"] = true
        end
      end

      track
    else
      Rails.logger.warn "SoundCloud V1 API Error (get_track): #{response.code} #{response.message}. Attempting V2 Fallback..."
      # If V1 fails completely (e.g. 403 Forbidden with new token), try full V2 fetch
      get_v2_track_complete(track_id)
    end
  rescue JSON::ParserError => e
    Rails.logger.error "SoundCloud JSON Parse Error (get_track): #{e.message}"
    nil
  end

  private

  # Fetches both metadata and stream using V2 API
  def get_v2_track_complete(track_id)
    # 1. Get Metadata
    uri = URI("https://api-v2.soundcloud.com/tracks/#{track_id}")
    params = { client_id: PUBLIC_V2_CLIENT_ID }
    uri.query = URI.encode_www_form(params)

    headers = { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" }
    token = self.class.access_token
    headers["Authorization"] = "OAuth #{token}" if token

    response = Net::HTTP.get_response(uri, headers)
    return nil unless response.is_a?(Net::HTTPSuccess)

    track = JSON.parse(response.body)

    # 2. Get Stream URL
    # We can reuse the existing logic, or duplicate for clarity. Reusing logic:
    if track["media"] && track["media"]["transcodings"]
       stream = track["media"]["transcodings"].find { |t| t["format"]["protocol"] == "hls" } ||
                track["media"]["transcodings"].find { |t| t["format"]["protocol"] == "progressive" }

       if stream
         stream_url = stream["url"]
         auth_token = track["track_authorization"]

         uri = URI(stream_url)
         params = { client_id: PUBLIC_V2_CLIENT_ID, track_authorization: auth_token }
         uri.query = URI.encode_www_form(params)

         res = Net::HTTP.get_response(uri, headers)
         if res.is_a?(Net::HTTPSuccess)
           track["stream_url"] = JSON.parse(res.body)["url"]
           track["is_direct_stream"] = true
         end
       end
    end

    track
  end

  # Resolves a full stream URL using the V2 API and a Public Client ID
  def resolve_v2_stream(track_id)
    # 1. Get V2 Track Metadata
    uri = URI("https://api-v2.soundcloud.com/tracks/#{track_id}")
    params = { client_id: PUBLIC_V2_CLIENT_ID }
    uri.query = URI.encode_www_form(params)

    # Spoof User-Agent to ensure access
    headers = { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" }

    # Add Authorization if available (Required for Go+ content)
    token = self.class.access_token
    headers["Authorization"] = "OAuth #{token}" if token

    response = Net::HTTP.get_response(uri, headers)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      return nil unless data["media"] && data["media"]["transcodings"]

      # 2. Find Progressive (mp3) or HLS stream
      # Prefer HLS for better streaming support
      stream = data["media"]["transcodings"].find { |t| t["format"]["protocol"] == "hls" } ||
               data["media"]["transcodings"].find { |t| t["format"]["protocol"] == "progressive" }

      return nil unless stream

      # 3. Resolve the actual stream URL
      stream_url = stream["url"]
      auth_token = data["track_authorization"]

      uri = URI(stream_url)
      params = { client_id: PUBLIC_V2_CLIENT_ID, track_authorization: auth_token }
      uri.query = URI.encode_www_form(params)

      # IMPORTANT: Must include Auth header here too
      res = Net::HTTP.get_response(uri, headers)
      if res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body)["url"]
      else
        Rails.logger.error "SoundCloud V2 Stream Resolve Failed: #{res.code}"
        nil
      end
    else
      Rails.logger.error "SoundCloud V2 Metadata Failed: #{response.code}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "SoundCloud V2 Resolve Error: #{e.message}"
    nil
  end

  # Checks current token validity and refreshes if needed.
  # Returns the access string.
  def self.ensure_valid_token
    # Bootstrap: If file missing, try to seed from environment variables or credentials
    unless File.exist?(TOKEN_FILE)
      access = ENV["SOUNDCLOUD_ACCESS_TOKEN"] || Rails.application.credentials.dig(:soundcloud, :access_token)
      refresh = ENV["SOUNDCLOUD_REFRESH_TOKEN"] || Rails.application.credentials.dig(:soundcloud, :refresh_token)

      if access.present? && refresh.present?
        # Create a dummy data structure that will trigger an immediate refresh or work as-is
        initial_data = {
          "access_token" => access,
          "refresh_token" => refresh,
          "expires_at" => Time.now.to_i + 3600 # Assume valid for 1 hour initially
        }
        File.write(TOKEN_FILE, JSON.pretty_generate(initial_data))
        Rails.logger.info "SoundCloud: Bootstrapped token file from environment/credentials."
      else
        Rails.logger.error "SoundCloud Token File missing and no environment variables found."
        return nil
      end
    end

    data = JSON.parse(File.read(TOKEN_FILE))

    # Check if expired (buffer of 60 seconds)
    if Time.now.to_i >= (data["expires_at"] || 0) - 60
      refresh_token(data["refresh_token"])
    else
      data["access_token"]
    end
  rescue JSON::ParserError => e
    Rails.logger.error "SoundCloud Token File Corrupt: #{e.message}"
    nil
  end

  # Performs the refresh token exchange and saves the new tokens.
  def self.refresh_token(current_refresh_token)
    Rails.logger.info "Refreshing SoundCloud Access Token..."

    uri = URI("https://api.soundcloud.com/oauth2/token")
    params = {
      client_id: PUBLIC_V2_CLIENT_ID, # MUST use the Public ID (Web Client) for this token
      client_secret: CLIENT_SECRET, # Note: Public client might not need a secret, or this might fail
      grant_type: "refresh_token",
      refresh_token: current_refresh_token
    }

    # If the public client doesn't use a secret, we should probably omit it.
    # Standard OAuth for public clients (SPA) usually omits client_secret.
    # Let's try sending it first; if it fails, we might need to remove it.

    response = Net::HTTP.post_form(uri, params)

    if response.is_a?(Net::HTTPSuccess)
      new_data = JSON.parse(response.body)

      # Calculate new absolute expiration
      new_data["expires_at"] = Time.now.to_i + new_data["expires_in"].to_i

      # Save to file
      File.write(TOKEN_FILE, JSON.pretty_generate(new_data))
      Rails.logger.info "SoundCloud Token Refreshed Successfully."

      new_data["access_token"]
    else
      Rails.logger.error "SoundCloud Refresh Failed: #{response.code} #{response.body}"
      nil
    end
  end
end
