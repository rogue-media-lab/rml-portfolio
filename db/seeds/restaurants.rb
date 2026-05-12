# El Mexicano Restaurant Seed
puts "Seeding El Mexicano..."

el_mexicano = Restaurant.find_or_create_by!(slug: "el-mexicano") do |r|
  r.name = "El Mexicano"
  r.tagline = "Authentic Mexican Flavors, Made With Heart"
  r.address = "401 N Main St, Clover, SC 29710"
  r.phone = "(803) 222-1838"
  r.email = "admin@elmexicano.com"
  r.place_id = "ChIJeTI3VEvsVogR39K1AcGkr2Y"
  r.rating = 4.3
  r.review_count = 997
  r.price_level = "$"
  r.service_type = "Dine-in, Takeout, Beer & Wine, Margaritas"
  r.primary_color = "#FDD835"
  r.accent_color = "#A10035"
  r.dark_color = "#1A237E"
  r.font_display = "Lilita One"
  r.font_body = "Nunito"
end

# Hours
puts "  Seeding hours..."
Hour.where(restaurant: el_mexicano).destroy_all
[
  { day_of_week: 0, open_time: "11:00", close_time: "22:00" },  # Monday
  { day_of_week: 1, open_time: "11:00", close_time: "22:00" },  # Tuesday
  { day_of_week: 2, open_time: "11:00", close_time: "22:00" },  # Wednesday
  { day_of_week: 3, open_time: "11:00", close_time: "22:00" },  # Thursday
  { day_of_week: 4, open_time: "11:00", close_time: "22:30" },  # Friday
  { day_of_week: 5, open_time: "11:00", close_time: "22:30" },  # Saturday
  { day_of_week: 6, open_time: "11:00", close_time: "22:00" }  # Sunday
].each do |hour_data|
  el_mexicano.hours.create!(hour_data)
end

# Menu Categories
puts "  Seeding menu categories..."
categories = {
  "Appetizers" => [
    { name: "Guacamole", description: "Fresh made guacamole with chips", price: 8.99, featured: true },
    { name: "Queso Dip", description: "Creamy cheese dip with chips", price: 6.99 },
    { name: "Nachos Supreme", description: "Loaded nachos with all the toppings", price: 10.99 }
  ],
  "Fajitas" => [
    { name: "Chicken Fajitas", description: "Sizzling chicken with peppers and onions", price: 14.99, featured: true },
    { name: "Steak Fajitas", description: "Sizzling steak with peppers and onions", price: 16.99 },
    { name: "Hawaiian Fajita Quesadilla", description: "Quesadilla with pineapple and fajita filling", price: 13.99, featured: true }
  ],
  "Tacos" => [
    { name: "Tacos de Asada", description: "Grilled steak tacos with cilantro and onion", price: 12.99, featured: true },
    { name: "Carnitas Plate", description: "Slow roasted pork with rice and beans", price: 13.99, featured: true },
    { name: "Fish Tacos", description: "Battered fish with cabbage slaw", price: 11.99 }
  ],
  "Enchiladas" => [
    { name: "Enchiladas Verdes", description: "Chicken enchiladas with green sauce", price: 11.99 },
    { name: "Enchiladas Rojas", description: "Cheese enchiladas with red sauce", price: 10.99 }
  ],
  "Burritos" => [
    { name: "Burrito Grande", description: "Large burrito with your choice of meat", price: 11.99 },
    { name: "Wet Burrito", description: "Smothered burrito with sauce and cheese", price: 12.99 }
  ],
  "Drinks" => [
    { name: "Margarita", description: "Classic lime margarita", price: 7.99 },
    { name: "Horchata", description: "Traditional rice drink", price: 3.99 },
    { name: "Jarritos", description: "Mexican soda", price: 2.99 }
  ]
}

categories.each_with_index do |(category_name, items), index|
  category = el_mexicano.menu_categories.find_or_create_by!(name: category_name) do |c|
    c.sort_order = index
    c.active = true
  end

  items.each do |item_data|
    category.menu_items.find_or_create_by!(name: item_data[:name]) do |item|
      item.restaurant = el_mexicano
      item.description = item_data[:description]
      item.price = item_data[:price]
      item.featured = item_data[:featured] || false
      item.active = true
    end
  end
end

# Testimonials
puts "  Seeding testimonials..."
[
  { customer_name: "Maria G.", quote: "Best Mexican food in Clover! The fajitas are amazing.", stars: 5, featured: true },
  { customer_name: "John D.", quote: "Great margaritas and friendly staff. Our go-to spot.", stars: 5, featured: true },
  { customer_name: "Sarah T.", quote: "Authentic flavors and generous portions. Highly recommend!", stars: 5, featured: true }
].each do |testimonial_data|
  el_mexicano.testimonials.find_or_create_by!(customer_name: testimonial_data[:customer_name]) do |t|
    t.quote = testimonial_data[:quote]
    t.stars = testimonial_data[:stars]
    t.featured = testimonial_data[:featured]
    t.active = true
  end
end

puts "El Mexicano seeded! (#{el_mexicano.menu_items.count} items in #{el_mexicano.menu_categories.count} categories)"

# Italian Garden Restaurant Seed
puts "\nSeeding Italian Garden..."

italian_garden = Restaurant.find_or_create_by!(slug: "italian-garden") do |r|
  r.name = "Italian Garden"
  r.tagline = "Authentic Italian Cuisine in York, SC"
  r.address = "York, SC"
  r.primary_color = "#4CAF50"
  r.accent_color = "#D32F2F"
  r.dark_color = "#1B5E20"
  r.font_display = "Playfair Display"
  r.font_body = "Open Sans"
end

# Hours
puts "  Seeding hours..."
Hour.where(restaurant: italian_garden).destroy_all
[
  { day_of_week: 0, open_time: "11:00", close_time: "21:00" },
  { day_of_week: 1, open_time: "11:00", close_time: "21:00" },
  { day_of_week: 2, open_time: "11:00", close_time: "21:00" },
  { day_of_week: 3, open_time: "11:00", close_time: "21:00" },
  { day_of_week: 4, open_time: "11:00", close_time: "22:00" },
  { day_of_week: 5, open_time: "11:00", close_time: "22:00" },
  { day_of_week: 6, open_time: "12:00", close_time: "21:00" }
].each do |hour_data|
  italian_garden.hours.create!(hour_data)
end

# Menu Categories
puts "  Seeding menu categories..."
ig_categories = {
  "Pasta" => [
    { name: "Spaghetti & Meatballs", description: "Classic spaghetti with homemade meatballs", price: 12.99, featured: true },
    { name: "Fettuccine Alfredo", description: "Creamy alfredo sauce with fettuccine", price: 11.99 },
    { name: "Lasagna", description: "Layered pasta with meat sauce and cheese", price: 13.99, featured: true }
  ],
  "Pizza" => [
    { name: "Margherita Pizza", description: "Fresh mozzarella, tomato, and basil", price: 10.99, featured: true },
    { name: "Pepperoni Pizza", description: "Classic pepperoni with mozzarella", price: 11.99 },
    { name: "Supreme Pizza", description: "Loaded with all the toppings", price: 14.99 }
  ],
  "Salads" => [
    { name: "Caesar Salad", description: "Romaine, croutons, parmesan, caesar dressing", price: 8.99 },
    { name: "Garden Salad", description: "Mixed greens with fresh vegetables", price: 7.99 }
  ]
}

ig_categories.each_with_index do |(category_name, items), index|
  category = italian_garden.menu_categories.find_or_create_by!(name: category_name) do |c|
    c.sort_order = index
    c.active = true
  end

  items.each do |item_data|
    category.menu_items.find_or_create_by!(name: item_data[:name]) do |item|
      item.restaurant = italian_garden
      item.description = item_data[:description]
      item.price = item_data[:price]
      item.featured = item_data[:featured] || false
      item.active = true
    end
  end
end

# Testimonials
puts "  Seeding testimonials..."
[
  { customer_name: "Pat R.", quote: "Best Italian food in York County. The lasagna is incredible!", stars: 5, featured: true },
  { customer_name: "Mike S.", quote: "Family-friendly atmosphere and delicious pizza.", stars: 5, featured: true }
].each do |testimonial_data|
  italian_garden.testimonials.find_or_create_by!(customer_name: testimonial_data[:customer_name]) do |t|
    t.quote = testimonial_data[:quote]
    t.stars = testimonial_data[:stars]
    t.featured = testimonial_data[:featured]
    t.active = true
  end
end

puts "Italian Garden seeded! (#{italian_garden.menu_items.count} items in #{italian_garden.menu_categories.count} categories)"
puts "\nDone! Total restaurants: #{Restaurant.count}"
