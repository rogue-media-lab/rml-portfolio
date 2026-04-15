namespace :rocky do
  desc "Import tones from tones/ directory into Active Storage"
  task import_tones: :environment do
    tones_dir = Rails.root.join("tones")

    unless Dir.exist?(tones_dir)
      puts "No tones/ directory found at #{tones_dir}. Create it and add audio files."
      next
    end

    imported = 0
    skipped = 0

    Dir.glob("#{tones_dir}/**/*.{mp3,wav,ogg,m4a}").sort.each do |file_path|
      basename = File.basename(file_path, ".*")
      description = basename.gsub(/[-_]/, " ").strip

      tone = Tone.find_or_initialize_by(name: basename)

      if tone.persisted? && tone.audio_file.attached?
        puts "  Skipping #{basename} (already imported)"
        skipped += 1
        next
      end

      tone.description = description unless tone.description.present?
      tone.audio_file.attach(
        io: File.open(file_path),
        filename: File.basename(file_path),
        content_type: "audio/mpeg"
      )

      if tone.save
        puts "  Imported: #{basename}"
        imported += 1
      else
        puts "  Failed: #{basename} — #{tone.errors.full_messages.join(', ')}"
      end
    end

    puts "\nDone. #{imported} imported, #{skipped} skipped."
  end

  desc "Backfill tone descriptions from tone_index.json"
  task backfill_tone_descriptions: :environment do
    index_path = Rails.root.join("tones", "tone_index.json")

    unless File.exist?(index_path)
      puts "tone_index.json not found at #{index_path}"
      next
    end

    index = JSON.parse(File.read(index_path))
    updated = 0
    missing = 0

    index.each do |description, filename|
      name = File.basename(filename, ".*")
      tone = Tone.find_by(name: name)

      if tone
        tone.update!(description: description)
        puts "  Updated: #{name} → #{description}"
        updated += 1
      else
        puts "  Missing: #{name} (not in DB)"
        missing += 1
      end
    end

    puts "\nDone. #{updated} updated, #{missing} missing."
  end
end
