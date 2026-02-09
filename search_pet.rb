# frozen_string_literal: true

require_relative "config/environment"

def search_pet
  service = SoundCloudService.new
  query = "Korn"
  puts "Searching for '#{query}'..."

  tracks = service.search(query)
  puts "Found #{tracks.size} results."

  tracks.each do |track|
    puts "- #{track['title']} (#{track['user']['username']}) [ID: #{track['id']}]"
    puts "  Policy: #{track['policy']}" if track['policy']
    puts "  Monetization: #{track['monetization_model']}" if track['monetization_model']
  end
end

search_pet
