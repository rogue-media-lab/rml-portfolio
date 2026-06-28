# CarUs seed data — idempotent
puts "=== Seeding CarUs ==="

# Habibi Mobile Auto Service
habibi = CarUs::Shop.find_or_create_by!(slug: "habibi-mobile") do |s|
  s.name = "Habibi Mobile Auto Service"
  s.address = "10065 Marsh Ln, Dallas, TX 75229"
  s.phone = "(469) 894-1694"
  s.email = "habibi@example.com"
  s.description = "Mobile mechanic serving North Dallas. We come to you — text us your location, vehicle type, and issue."
  s.active = true
end
puts "  Shop: #{habibi.name} (#{habibi.slug})"

# Technician account
tech = Technician.find_or_create_by!(email: "habibi@example.com") do |t|
  t.password = "password123"
  t.password_confirmation = "password123"
  t.shop = habibi
end
puts "  Technician: #{tech.email}"

# Demo Services
services = [
  { name: "Oil Change", description: "Full synthetic oil change with filter. We come to your location.", price: 59.99, duration_minutes: 45 },
  { name: "Brake Pad Replacement", description: "Front or rear brake pad replacement with ceramic pads.", price: 149.99, duration_minutes: 90 },
  { name: "Diagnostic Scan", description: "Check engine light? We'll scan and diagnose the issue on-site.", price: 49.99, duration_minutes: 30 },
  { name: "Battery Replacement", description: "Dead battery? We'll test, replace, and dispose of the old one.", price: 129.99, duration_minutes: 20 },
  { name: "A/C Service", description: "A/C performance check and recharge. Stay cool in the Texas heat.", price: 89.99, duration_minutes: 60 }
]

services.each do |svc|
  CarUs::Service.find_or_create_by!(shop: habibi, name: svc[:name]) do |s|
    s.description = svc[:description]
    s.price = svc[:price]
    s.duration_minutes = svc[:duration_minutes]
    s.active = true
  end
end
puts "  Services: #{habibi.services.count}"

# Demo Flash Alerts (one active, one expired)
unless habibi.flash_alerts.exists?(title: "30% Off Brake Service")
  habibi.flash_alerts.create!(
    technician: tech,
    title: "30% Off Brake Service",
    description: "Limited time! Front or rear brake pads — we come to you. Dallas only.",
    discount_percentage: 30,
    duration_hours: 48,
    active: true
  )
end

unless habibi.flash_alerts.exists?(title: "Free Oil Change with Brake Job")
  habibi.flash_alerts.create!(
    technician: tech,
    title: "Free Oil Change with Brake Job",
    description: "Book any brake service this week and get a free synthetic oil change.",
    discount_percentage: 100,
    duration_hours: 168,
    active: true
  )
end

puts "  Flash Alerts: #{habibi.flash_alerts.count}"

puts "=== CarUs seed complete ==="
