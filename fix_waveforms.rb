songs_to_fix = Song.joins(:audio_file_attachment).left_outer_joins(:waveform_data_attachment).where(active_storage_attachments: { id: nil })

puts "Found #{songs_to_fix.count} songs needing waveform generation."

songs_to_fix.each do |song|
  puts "Enqueuing GenerateWaveformJob for: #{song.title} (ID: #{song.id})"
  GenerateWaveformJob.perform_later(song)
end
