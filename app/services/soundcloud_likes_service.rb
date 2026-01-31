# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# Fetches a user's liked tracks from SoundCloud using V1 API.
class SoundcloudLikesService
  BASE_URL = "https://api.soundcloud.com"
  PROFILE_URL = "https://soundcloud.com/mason-roberts-939574766"

  def self.fetch_likes
    new.fetch_likes
  end

  def fetch_likes
    token = SoundCloudService.access_token
    return [] unless token

    user_id = get_user_id(token)
    return [] unless user_id

    uri = URI("#{BASE_URL}/users/#{user_id}/favorites")
    params = {
      limit: 50
    }
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "OAuth #{token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      tracks = JSON.parse(response.body)
      # Wrap tracks to match V2 structure expected by controller: { "track" => track_data }
      tracks.map { |track| { "track" => track } }
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
    # Try the /me endpoint first since we have a user token
    uri = URI("#{BASE_URL}/me")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "OAuth #{token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      return JSON.parse(response.body)["id"]
    end

    # Fallback to resolve if /me fails
    uri = URI("#{BASE_URL}/resolve")
    params = {
      url: PROFILE_URL
    }
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "OAuth #{token}"

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