namespace :waypoint do
  desc "Import labor times from the SQLite working copy (JSON export) into Postgres"
  task import_labor_times: :environment do
    path = ENV.fetch("FILE", "/tmp/labor_times.json")
    rows = JSON.parse(File.read(path))
    created = updated = skipped = 0

    rows.each do |r|
      service = r["service"].to_s.strip
      if service.blank? || r["hours"].nil?
        skipped += 1
        next
      end

      attrs = {
        category:    r["category"].presence,
        hours:       r["hours"].to_f,
        notes:       r["notes"].presence,
        make:        r["make"].presence,
        model:       r["model"].presence,
        year_start:  r["year_start"].presence,
        year_end:    r["year_end"].presence,
        generation:  r["generation"].presence
      }

      record = CarUs::LaborTime.find_or_initialize_by(
        service: service,
        make: attrs[:make],
        model: attrs[:model],
        year_start: attrs[:year_start],
        year_end: attrs[:year_end]
      )

      if record.new_record?
        record.assign_attributes(attrs)
        record.save!
        created += 1
      else
        record.assign_attributes(attrs)
        if record.changed?
          record.save!
          updated += 1
        end
      end
    end

    puts "labor times: #{created} created, #{updated} updated, #{skipped} skipped, #{CarUs::LaborTime.count} total"
  end
end
