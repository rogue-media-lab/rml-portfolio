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
  PUBLIC_V2_CLIENT_ID = Rails.application.credentials.dig(:soundcloud, :public_v2_client_id) || "KKzJxmw11tYpCs6T24P4uUYhqmjalG6M"

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
    auth_headers = headers.merge("Authorization" => "OAuth #{token}") if token

    response = Net::HTTP.get_response(uri, auth_headers || headers)

    # Fallback to no-auth for metadata
    if response.code == "403"
      response = Net::HTTP.get_response(uri, headers)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    track = JSON.parse(response.body)

    # 2. Get Stream URL
    if track["media"] && track["media"]["transcodings"]
       stream = track["media"]["transcodings"].find { |t| t["format"]["protocol"] == "hls" } ||
                track["media"]["transcodings"].find { |t| t["format"]["protocol"] == "progressive" }

       if stream
         stream_url = stream["url"]
         auth_token = track["track_authorization"]

         uri = URI(stream_url)
         params = { client_id: PUBLIC_V2_CLIENT_ID, track_authorization: auth_token }
         uri.query = URI.encode_www_form(params)

         res = Net::HTTP.get_response(uri, auth_headers || headers)
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
    auth_headers = headers.merge("Authorization" => "OAuth #{token}") if token

    # Try with auth first
    response = Net::HTTP.get_response(uri, auth_headers || headers)

    # FALLBACK: Try without auth if 403 (Sometimes works for restricted metadata)
    if response.code == "403"
      response = Net::HTTP.get_response(uri, headers)
    end

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

      # IMPORTANT: Must include Auth header here too for Go+ content
      res = Net::HTTP.get_response(uri, auth_headers || headers)
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
    # 1. Bootstrap from token_seed if file missing
    unless File.exist?(TOKEN_FILE)
      seed_json = Rails.application.credentials.dig(:soundcloud, :token_seed)
      if seed_json.present?
        begin
          # Fix known typo in credentials
          fixed_json = seed_json.sub(', xpires_at"', ',"expires_at"')
          seed_data = JSON.parse(fixed_json)

          # Ensure correct Client ID is saved with the token
          # We know this specific seed uses the default public ID
          seed_data["client_id"] = "KKzJxmw11tYpCs6T24P4uUYhqmjalG6M"

          File.write(TOKEN_FILE, JSON.pretty_generate(seed_data))
          Rails.logger.info "SoundCloud: Bootstrapped token file from credentials token_seed."
        rescue JSON::ParserError => e
          Rails.logger.error "SoundCloud: Failed to parse token_seed: #{e.message}"
        end
      end
    end

    # 2. Try to read and use/refresh existing token
    if File.exist?(TOKEN_FILE)
      begin
        data = JSON.parse(File.read(TOKEN_FILE))
        # Check if expired (buffer of 60 seconds)
        exp_at = data["expires_at"] || 0
        if Time.now.to_i >= exp_at - 60
          return refresh_token(data["refresh_token"], data["client_id"])
        else
          return data["access_token"]
        end
      rescue JSON::ParserError, StandardError => e
        Rails.logger.error "SoundCloud Token File Error: #{e.message}. Attempting fallback."
      end
    end

    # 3. Last resort: Client Credentials Flow
    client_credentials_token
  end

  # Obtains a token via Client Credentials flow (no user-specific access)
  def self.client_credentials_token
    Rails.logger.info "Requesting SoundCloud Client Credentials Token..."
    uri = URI("https://api.soundcloud.com/oauth2/token")
    params = {
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      grant_type: "client_credentials"
    }

    response = Net::HTTP.post_form(uri, params)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      # Note: Client credentials tokens usually don't have refresh tokens
      data["access_token"]
    else
      Rails.logger.error "SoundCloud Client Credentials Failed: #{response.code} #{response.body}"
      nil
    end
  end

  # Performs the refresh token exchange and saves the new tokens.
  def self.refresh_token(current_refresh_token, token_client_id = nil)
    return client_credentials_token if current_refresh_token.blank?

    Rails.logger.info "Refreshing SoundCloud Access Token..."
    Rails.logger.info "Using Client ID for Refresh: #{token_client_id || CLIENT_ID}"

    uri = URI("https://api.soundcloud.com/oauth2/token")

    # Use the specific client_id associated with the token if known, otherwise try official
    primary_client_id = token_client_id || CLIENT_ID

    params = {
      client_id: primary_client_id,
      grant_type: "refresh_token",
      refresh_token: current_refresh_token
    }

    # Only add secret if using the official app client
    params[:client_secret] = CLIENT_SECRET if primary_client_id == CLIENT_ID

    response = Net::HTTP.post_form(uri, params)

    # Fallback logic: If primary failed and it wasn't the default public one, try the default public one
    if !response.is_a?(Net::HTTPSuccess) && primary_client_id != "KKzJxmw11tYpCs6T24P4uUYhqmjalG6M"
      Rails.logger.warn "SoundCloud Refresh with #{primary_client_id} Failed. Retrying with Default Public Client..."
      params[:client_id] = "KKzJxmw11tYpCs6T24P4uUYhqmjalG6M"
      params.delete(:client_secret)
      response = Net::HTTP.post_form(uri, params)
      token_client_id = "KKzJxmw11tYpCs6T24P4uUYhqmjalG6M" if response.is_a?(Net::HTTPSuccess)
    end

    if response.is_a?(Net::HTTPSuccess)
      new_data = JSON.parse(response.body)

      # Calculate new absolute expiration
      new_data["expires_at"] = Time.now.to_i + new_data["expires_in"].to_i

      # Persist the working client_id for future refreshes
      new_data["client_id"] = token_client_id || params[:client_id]

      # Save to file
      File.write(TOKEN_FILE, JSON.pretty_generate(new_data))
      Rails.logger.info "SoundCloud Token Refreshed Successfully."

      new_data["access_token"]
    else
      Rails.logger.error "SoundCloud Refresh Failed: #{response.code} #{response.body}. Falling back to Client Credentials."
      client_credentials_token
    end
  end
end
