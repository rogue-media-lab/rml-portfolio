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

# Create technician account for Habibi's owner
tech = Technician.find_or_create_by!(email: "habibi@example.com") do |t|
  t.password = "password123"
  t.password_confirmation = "password123"
  t.shop = habibi
end
puts "  Technician: #{tech.email} (shop: #{tech.shop.name})"

puts "=== CarUs seed complete ==="