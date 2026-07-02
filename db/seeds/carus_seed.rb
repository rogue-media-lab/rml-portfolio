# CarUs Seed — imports from vehicle_data.db JSON export
# One-time: rails db:seed:carus  (or rails db:seed)

require "json"

puts "=== CarUs Seed ==="

# ── Demo CarOwner ──────────────────────────────────────────────
demo = CarOwner.find_or_create_by!(email: "demo@carus.app") do |owner|
  owner.password = "password123"
  owner.password_confirmation = "password123"
end
puts "  CarOwner: #{demo.email}"

# ── Labor Times ─────────────────────────────────────────────────
if defined?(CarUs::LaborTime) && CarUs::LaborTime.table_exists?
  labor_data = JSON.parse(File.read(Rails.root.join("db/seeds/data/labor_times.json")))
  labor_data.each do |lt|
    CarUs::LaborTime.find_or_create_by!(service: lt["service"]) do |l|
      l.category = lt["category"]
      l.hours = lt["hours"]
    end
  end
  puts "  LaborTimes: #{CarUs::LaborTime.count}"
end

# ── Vehicles ────────────────────────────────────────────────────
vehicle_data = JSON.parse(File.read(Rails.root.join("db/seeds/data/vehicles.json")))
vehicle_id_map = {} # old SQLite id → new AR id

vehicle_data.each do |v|
  next if v["vin"].present? && CarUs::Vehicle.exists?(vin: v["vin"])

  vehicle = demo.vehicles.find_or_create_by!(vin: v["vin"].presence) do |veh|
    veh.year = v["year"]
    veh.make = v["make"]
    veh.model = v["model"]
    veh.trim = v["trim"]
    veh.engine_size = v["engine_size"]
    veh.transmission = v["transmission"]
    veh.mileage = v["mileage_in"]
  end
  vehicle_id_map[v["id"]] = vehicle.id
end
puts "  Vehicles: #{vehicle_data.size} (map: #{vehicle_id_map.size})"

# ── Service Records (jobs) ──────────────────────────────────────
job_data = JSON.parse(File.read(Rails.root.join("db/seeds/data/jobs.json")))

job_data.each do |j|
  vehicle_id = vehicle_id_map[j["vehicle_id"]]
  next unless vehicle_id

  CarUs::ServiceRecord.find_or_create_by!(
    vehicle_id: vehicle_id,
    description: j["description"],
    service_date: Date.parse(j["start_date"] || j["created_at"] || "2026-01-01")
  ) do |sr|
    sr.mileage = j["mileage_at_service"]
    sr.technician_name = "Mason R."
    sr.cost = j["total_parts_cost"] || j["total_labor_cost"]
  end
end
puts "  ServiceRecords: #{job_data.size}"

# ── Parts ───────────────────────────────────────────────────────
part_data = JSON.parse(File.read(Rails.root.join("db/seeds/data/job_parts.json")))
# job_parts reference old SQLite job_ids — skip for now unless we map
puts "  Parts: #{part_data.size} (stored as JSON, not yet mapped)"

# ── Procedures ──────────────────────────────────────────────────
proc_data = JSON.parse(File.read(Rails.root.join("db/seeds/data/procedures.json")))
puts "  Procedures: #{proc_data.size} (stored as JSON, not yet mapped)"

puts "=== Seed complete ==="
