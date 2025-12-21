# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# Handles all communication with the SoundCloud API.
class SoundCloudService
  BASE_URL = "https://api-v2.soundcloud.com"
  CLIENT_ID = CLIENT_ID = ENV['SOUNDCLOUD_CLIENT_ID'] || Rails.application.credentials.dig(:soundcloud, :client_id)

  # Searches for tracks on SoundCloud based on a query.
  #
  # @param query [String] The search term (e.g., genre, artist).
  # @return [Array] An array of track data.
  def search(query)
    uri = URI("#{BASE_URL}/search/tracks")
    params = {
      q: query,
      client_id: CLIENT_ID,
      limit: 10 # Let's limit to 10 results for now
    }
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

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

  # Retrieves the final HLS stream URL for a given track ID.
  #
  # @param track_id [String] The ID of the SoundCloud track.
  # @return [String, nil] The HLS stream URL or nil if not found.
  def get_stream_url(track_id)
    # TODO: Implement the multi-step process to get the stream URL.
    # 1. Fetch track metadata.
    # 2. Extract the HLS stream URL template.
    # 3. Get track authorization.
    # 4. Construct the final, authorized URL.
    puts "Fetching stream URL for track: #{track_id}"
    nil # Return nil for now.
  end

  # Fetches a single track from the SoundCloud API.
  #
  # @param track_id [String] The ID of the SoundCloud track.
  # @return [Hash, nil] A hash representing the track object, or nil if not found.
  def get_track(track_id)
    uri = URI("#{BASE_URL}/tracks/#{track_id}")
    params = { client_id: CLIENT_ID }
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "SoundCloud API Error (get_track): #{response.code} #{response.message}"
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error "SoundCloud JSON Parse Error (get_track): #{e.message}"
    nil
  end
end
