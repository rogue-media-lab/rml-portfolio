song = Song.last
puts "Song: #{song.title}"
puts "Audio URL (.url): #{song.audio_file.attached? ? song.audio_file.url : 'No Audio'}"
puts "Image URL (blob): #{song.image.attached? ? Rails.application.routes.url_helpers.rails_blob_url(song.image) : 'No Image'}"
