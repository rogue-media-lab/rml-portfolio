# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# Handles all communication with the SoundCloud API.
# Manages OAuth2 access and refresh tokens persistently in the database.
class SoundCloudService
  BASE_URL = "https://api-v2.soundcloud.com"
  CLIENT_ID = ENV["SOUNDCLOUD_CLIENT_ID"] || Rails.application.credentials.dig(:soundcloud, :client_id)
  CLIENT_SECRET = ENV["SOUNDCLOUD_CLIENT_SECRET"] || Rails.application.credentials.dig(:soundcloud, :client_secret)
  PUBLIC_V2_CLIENT_ID = Rails.application.credentials.dig(:soundcloud, :public_v2_client_id) || "KKzJxmw11tYpCs6T24P4uUYhqmjalG6M"

  # Retrieves a valid access token, refreshing it if necessary.
  def self.access_token
    ensure_valid_token
  end

  # Searches for tracks on SoundCloud based on a query.
  def search(query)
    uri = URI("#{BASE_URL}/search/tracks")
    params = { q: query, limit: 10 }
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

  # Fetches a single track from the SoundCloud API.
  def get_track(track_id)
    token = self.class.access_token
    return nil unless token

    uri = URI("https://api.soundcloud.com/tracks/#{track_id}")
    headers = { "Authorization" => "OAuth #{token}" }

    response = Net::HTTP.get_response(uri, headers)

    if response.is_a?(Net::HTTPSuccess)
      track = JSON.parse(response.body)

      if !track.key?("media")
        Rails.logger.info "SoundCloud: V1 track likely restricted. Attempting V2 resolve with Public ID..."
        v2_stream = resolve_v2_stream(track_id)
        if v2_stream
          track["stream_url"] = v2_stream
          track["is_direct_stream"] = true
        end
      end
      track
    else
      Rails.logger.warn "SoundCloud V1 API Error (get_track): #{response.code} #{response.message}. Attempting V2 Fallback..."
      get_v2_track_complete(track_id)
    end
  rescue JSON::ParserError => e
    Rails.logger.error "SoundCloud JSON Parse Error (get_track): #{e.message}"
    nil
  end

  private

  def get_v2_track_complete(track_id)
    uri = URI("https://api-v2.soundcloud.com/tracks/#{track_id}")
    params = { client_id: PUBLIC_V2_CLIENT_ID }
    uri.query = URI.encode_www_form(params)

    headers = { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" }
    token = self.class.access_token
    auth_headers = headers.merge("Authorization" => "OAuth #{token}") if token

    response = Net::HTTP.get_response(uri, auth_headers || headers)
    response = Net::HTTP.get_response(uri, headers) if response.code == "403"

    return nil unless response.is_a?(Net::HTTPSuccess)
    track = JSON.parse(response.body)

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

  def resolve_v2_stream(track_id)
    uri = URI("https://api-v2.soundcloud.com/tracks/#{track_id}")
    params = { client_id: PUBLIC_V2_CLIENT_ID }
    uri.query = URI.encode_www_form(params)

    headers = { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" }
    token = self.class.access_token
    auth_headers = headers.merge("Authorization" => "OAuth #{token}") if token

    response = Net::HTTP.get_response(uri, auth_headers || headers)
    response = Net::HTTP.get_response(uri, headers) if response.code == "403"

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      return nil unless data["media"] && data["media"]["transcodings"]

      stream = data["media"]["transcodings"].find { |t| t["format"]["protocol"] == "hls" } ||
               data["media"]["transcodings"].find { |t| t["format"]["protocol"] == "progressive" }

      return nil unless stream
      stream_url = stream["url"]
      auth_token = data["track_authorization"]
      uri = URI(stream_url)
      params = { client_id: PUBLIC_V2_CLIENT_ID, track_authorization: auth_token }
      uri.query = URI.encode_www_form(params)

      res = Net::HTTP.get_response(uri, auth_headers || headers)
      if res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body)["url"]
      else
        nil
      end
    else
      nil
    end
  rescue StandardError
    nil
  end

  def self.ensure_valid_token
    # 1. Look for token in DB
    token_record = SoundcloudToken.first

    # 2. Bootstrap from token_seed if DB is empty
    if token_record.nil?
      seed_json = Rails.application.credentials.dig(:soundcloud, :token_seed)
      if seed_json.present?
        begin
          fixed_json = seed_json.sub(', xpires_at"', ',"expires_at"')
          seed_data = JSON.parse(fixed_json)
          
          token_record = SoundcloudToken.create!(
            access_token: seed_data["access_token"],
            refresh_token: seed_data["refresh_token"],
            expires_at: Time.at(seed_data["expires_at"] || (Time.now.to_i + 3600)),
            client_id: seed_data["client_id"] || "KKzJxmw11tYpCs6T24P4uUYhqmjalG6M"
          )
          Rails.logger.info "SoundCloud: Bootstrapped token from credentials into Database."
        rescue JSON::ParserError => e
          Rails.logger.error "SoundCloud: Failed to parse token_seed: #{e.message}"
        end
      end
    end

    return client_credentials_token if token_record.nil?

    # 3. Check expiration and refresh if needed
    if Time.now >= token_record.expires_at - 60.seconds
      refresh_token(token_record)
    else
      token_record.access_token
    end
  end

  def self.client_credentials_token
    uri = URI("https://api.soundcloud.com/oauth2/token")
    params = {
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      grant_type: "client_credentials"
    }
    response = Net::HTTP.post_form(uri, params)
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)["access_token"]
    else
      nil
    end
  end

  def self.refresh_token(token_record)
    Rails.logger.info "Refreshing SoundCloud Access Token from DB..."
    uri = URI("https://api.soundcloud.com/oauth2/token")
    
    # Try with the client_id stored in the record
    primary_client_id = token_record.client_id || CLIENT_ID
    params = {
      client_id: primary_client_id,
      grant_type: "refresh_token",
      refresh_token: token_record.refresh_token
    }
    params[:client_secret] = CLIENT_SECRET if primary_client_id == CLIENT_ID

    response = Net::HTTP.post_form(uri, params)

    # Fallback to default public client if primary fails
    if !response.is_a?(Net::HTTPSuccess) && primary_client_id != "KKzJxmw11tYpCs6T24P4uUYhqmjalG6M"
      params[:client_id] = "KKzJxmw11tYpCs6T24P4uUYhqmjalG6M"
      params.delete(:client_secret)
      response = Net::HTTP.post_form(uri, params)
    end

    if response.is_a?(Net::HTTPSuccess)
      new_data = JSON.parse(response.body)
      token_record.update!(
        access_token: new_data["access_token"],
        refresh_token: new_data["refresh_token"],
        expires_at: Time.now + new_data["expires_in"].to_i.seconds,
        client_id: params[:client_id]
      )
      Rails.logger.info "SoundCloud Token Refreshed and Saved to DB."
      token_record.access_token
    else
      Rails.logger.error "SoundCloud Refresh Failed: #{response.code}. Falling back to Client Credentials."
      client_credentials_token
    end
  end
end