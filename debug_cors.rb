require 'net/http'
require 'uri'

song = Song.last
url = song.audio_file.url
puts "Testing URL: #{url}"

uri = URI.parse(url)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Get.new(uri.request_uri)
request["Origin"] = "http://127.0.0.1:3000"

response = http.request(request)

puts "\nResponse Code: #{response.code}"
puts "CORS Headers Received:"
response.each_header do |key, value|
  puts "#{key}: #{value}" if key.downcase.include?('access-control')
end

if response['access-control-allow-origin']
  puts "\n✅ CORS Header Present!"
else
  puts "\n❌ CORS Header MISSING. S3 is rejecting the Origin."
end
