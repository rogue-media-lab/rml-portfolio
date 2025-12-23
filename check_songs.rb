Song.order(created_at: :desc).limit(10).each do |song|
  audio = song.audio_file.attached?
  waveform = song.waveform_data.attached?
  puts "ID: #{song.id} | Title: #{song.title} | Audio: #{audio} | Waveform: #{waveform}"
end
