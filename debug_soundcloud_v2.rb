# frozen_string_literal: true

require_relative "config/environment"
require "net/http"
require "uri"
require "json"

def debug_v2_likes
  puts "--- Debugging SoundCloud V2 Likes ---"

  # 1. Get Token
  token = SoundCloudService.access_token
  puts "Token retrieved: #{token.present?}"
  return unless token

  # 2. Get User ID (Use existing service logic for now)
  puts "Resolving User ID..."
  service = SoundcloudLikesService.new
  user_id = service.send(:get_user_id, token)
  puts "User ID: #{user_id}"
  return unless user_id

  # 3. Fetch Likes using V2
  puts "Fetching V2 Likes..."

  # Try with Official Client ID first
  puts "--- Attempt 1: Official Client ID + OAuth ---"
  uri = URI("https://api-v2.soundcloud.com/users/#{user_id}/likes")
  params = {
    limit: 50,
    offset: 0,
    client_id: SoundCloudService::CLIENT_ID # Add client_id
  }
  uri.query = URI.encode_www_form(params)

  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "OAuth #{token}"
  request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  if response.is_a?(Net::HTTPSuccess)
    process_response(response)
  else
    puts "Attempt 1 Failed: #{response.code}"

    # Try with Public V2 Client ID
    puts "--- Attempt 2: Public V2 Client ID + OAuth ---"
    params[:client_id] = SoundCloudService::PUBLIC_V2_CLIENT_ID
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "OAuth #{token}"
    request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      process_response(response)
    else
      puts "Attempt 2 Failed: #{response.code}"
      puts response.body
    end
  end
end

def process_response(response)
  data = JSON.parse(response.body)
  collection = data["collection"]

  puts "Found #{collection.size} likes."

  found_pet = false
  collection.each do |item|
    track = item["track"]
    next unless track # sometimes can be playlists?

    title = track["title"]
    artist = track["user"]["username"]
    puts "- #{title} by #{artist}"

    if title.downcase.include?("pet") && artist.downcase.include?("perfect circle")
      found_pet = true
      puts "!!! FOUND 'Pet' by 'A Perfect Circle' !!!"
    end
  end
  puts "Test Failed: 'Pet' not found." unless found_pet
end

debug_v2_likes
