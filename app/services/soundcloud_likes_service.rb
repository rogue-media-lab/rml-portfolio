# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# Fetches a user's liked tracks from SoundCloud using V2 API.
class SoundcloudLikesService
  # Switch to V2 API to see Go+ restricted tracks
  BASE_URL = "https://api-v2.soundcloud.com"
  PROFILE_URL = "https://soundcloud.com/mason-roberts-939574766"

  def self.fetch_likes
    new.fetch_likes
  end

  def fetch_likes
    token = SoundCloudService.access_token
    return [] unless token

    user_id = get_user_id(token)
    return [] unless user_id

    # V2 Endpoint: /users/:id/likes
    uri = URI("#{BASE_URL}/users/#{user_id}/likes")
    params = {
      limit: 50,
      client_id: SoundCloudService::PUBLIC_V2_CLIENT_ID
    }
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    # PUBLIC ACCESS: We do NOT send the OAuth token here.
    # Sending the token linked to our restricted app causes a 403 on V2.
    # We rely solely on the Public Client ID to view the public likes list.

    # Spoof UA to match web player behavior
    request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      # V2 returns { "collection" => [ { "track" => { ... } }, ... ] }
      # This matches the structure expected by the controller, so we just return the collection.
      data["collection"] || []
    else
      Rails.logger.error "SoundCloud Likes API Error: #{response.code} #{response.message}"
      []
    end
  rescue JSON::ParserError => e
    Rails.logger.error "SoundCloud Likes JSON Parse Error: #{e.message}"
    []
  end

  private

  def get_user_id(token)
    # Try the V1 /me endpoint first since we have a user token
    # (V1 is still fine for basic user info)
    uri = URI("https://api.soundcloud.com/me")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "OAuth #{token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      return JSON.parse(response.body)["id"]
    end

    # Try V2 /me (fallback for V2-only tokens)
    uri = URI("https://api-v2.soundcloud.com/me")
    params = { client_id: SoundCloudService::PUBLIC_V2_CLIENT_ID }
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "OAuth #{token}"
    request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      return JSON.parse(response.body)["id"]
    end

    # Fallback to resolve if /me fails
    uri = URI("https://api.soundcloud.com/resolve")
    params = {
      url: PROFILE_URL,
      client_id: SoundCloudService::PUBLIC_V2_CLIENT_ID # Use the same Client ID as the token
    }
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "OAuth #{token}"
    request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code == "302"
      # Location: https://api.soundcloud.com/users/soundcloud:users:579656895
      response["location"].split(":").last
    elsif response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)["id"]
    else
      Rails.logger.error "SoundCloud Resolve API Error: #{response.code} #{response.message}"
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error "SoundCloud Resolve JSON Parse Error: #{e.message}"
    nil
  end
end
