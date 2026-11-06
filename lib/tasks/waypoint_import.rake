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

  desc "Seed service parts from Mason's own job history (JSON export)"
  task import_service_parts: :environment do
    path = ENV.fetch("FILE", "/tmp/service_parts.json")
    rows = JSON.parse(File.read(path))
    labor_services = CarUs::LaborTime.distinct.pluck(:service).compact

    created = skipped = 0
    unattributed = []

    rows.each do |r|
      desc = r["job_description"].to_s

      # Only seed a part when the job it came from maps to ONE known service. A
      # multi-service repair order (one long free-text description) cannot be split
      # by part name without guessing, and a guessed attribution is a false record.
      matches = labor_services.select { |s| desc.downcase.include?(s.downcase) }

      if matches.size != 1
        unattributed << desc[0, 60]
        skipped += 1
        next
      end

      service = matches.first
      make  = r["make"].presence
      model = r["model"].presence
      year  = r["year"].presence
      name  = r["part_name"].to_s.strip
      next if name.blank?

      record = CarUs::ServicePart.find_or_initialize_by(
        service: service, part_name: name,
        make: make, model: model,
        year_start: year, year_end: year
      )

      if record.new_record?
        record.assign_attributes(
          part_number: r["part_number"].presence,
          oem_number: r["oem_number"].presence,
          quantity: r["quantity"].presence || 1,
          unit_cost: r["unit_cost"].presence,
          supplier: r["supplier"].presence,
          # single_source: true, but from exactly one job. It is what this tech used
          # on this car - stronger than a web claim, weaker than a verified cross-ref.
          confidence: "single_source",
          source: "own_job_history",
          verified_on_vehicle: true,
          notes: "From job: #{r['job_description'].to_s[0, 120]}"
        )
        record.save!
        created += 1
      else
        skipped += 1
      end
    end

    puts "service parts: #{created} created, #{skipped} skipped, #{CarUs::ServicePart.count} total"
    puts "unattributable to a single service: #{unattributed.uniq.size} distinct job(s)"
    unattributed.uniq.first(5).each { |d| puts "  - #{d}" }
  end
end
