# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# Fetches a user's liked tracks from SoundCloud.
class SoundcloudLikesService
  BASE_URL = "https://api-v2.soundcloud.com"
  PROFILE_URL = "https://soundcloud.com/mason-roberts-939574766"

  def self.fetch_likes
    new.fetch_likes
  end

  def fetch_likes
    return [] unless client_id

    user_id = get_user_id
    return [] unless user_id

    uri = URI("#{BASE_URL}/users/#{user_id}/likes")
    params = {
      client_id:,
      limit: 50 # Let's get a decent number of likes
    }
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)["collection"]
    else
      Rails.logger.error "SoundCloud Likes API Error: #{response.code} #{response.message}"
      []
    end
  rescue JSON::ParserError => e
    Rails.logger.error "SoundCloud Likes JSON Parse Error: #{e.message}"
    []
  end

  private

  def client_id
    @client_id ||= Rails.application.credentials.dig(:soundcloud, :client_id).tap do |id|
      Rails.logger.error "SoundCloud client_id is not configured." if id.nil?
    end
  end

  def get_user_id
    return nil unless client_id

    uri = URI("#{BASE_URL}/resolve")
    params = {
      url: PROFILE_URL,
      client_id:
    }
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
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
