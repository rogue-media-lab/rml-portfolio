# Multi-Tenant Restaurants — Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Move El Mexicano (and future restaurants) into the portfolio app as a subproject, eliminating separate Heroku deployments and hosting costs.

**Architecture:** Add a `Restaurant` model as the tenant. All restaurant-specific models (MenuCategory, MenuItem, etc.) get a `restaurant_id` foreign key. Routes use `/el-mexicano`, `/italian-garden`, etc. Admin lives under the existing MilkAdmin namespace. Each restaurant gets its own theme (colors, fonts) stored on the Restaurant model.

**Tech Stack:** Rails 8, PostgreSQL, Tailwind CSS, Hotwire (Turbo + Stimulus), Devise (existing MilkAdmin auth)

---

## Phase 1: Restaurant Model & Routing

### Task 1.1: Create Restaurant model and migration

**Objective:** Add the tenant model that everything else belongs to.

**Files:**
- Create: `db/migrate/YYYYMMDD_create_restaurants.rb`
- Create: `app/models/restaurant.rb`

**Migration:**
```ruby
class CreateRestaurants < ActiveRecord::Migration[8.0]
  def change
    create_table :restaurants do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :tagline
      t.string :address
      t.string :phone
      t.string :email
      t.string :place_id
      t.decimal :rating, precision: 2, scale: 1
      t.integer :review_count, default: 0
      t.string :price_level
      t.string :service_type

      # Theme
      t.string :primary_color, default: "#FDD835"
      t.string :accent_color, default: "#A10035"
      t.string :dark_color, default: "#1A237E"
      t.string :font_display, default: "Lilita One"
      t.string :font_body, default: "Nunito"

      # Images
      t.string :hero_image
      t.string :logo_image

      t.timestamps
    end

    add_index :restaurants, :slug, unique: true
  end
end
```

**Model:**
```ruby
class Restaurant < ApplicationRecord
  has_many :menu_categories, dependent: :destroy
  has_many :menu_items, through: :menu_categories
  has_many :testimonials, dependent: :destroy
  has_many :hours, dependent: :destroy
  has_many :reservations, dependent: :destroy
  has_many :orders, dependent: :destroy

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }

  # For URL generation
  def to_param
    slug
  end
end
```

**Verify:** `bin/rails db:migrate` succeeds, `Restaurant.create!(name: "Test", slug: "test")` works in console.

---

### Task 1.2: Add restaurant routes

**Objective:** Set up namespaced routes for each restaurant.

**Files:**
- Modify: `config/routes.rb`

**Add after `get "lab"` route:**
```ruby
# Restaurant platform
scope "/:restaurant_slug" do
  get "/", to: "restaurant/pages#home", as: :restaurant_home
  get "/menu", to: "restaurant/menu#index", as: :restaurant_menu
  get "/about", to: "restaurant/pages#about", as: :restaurant_about
  get "/contact", to: "restaurant/contact#index", as: :restaurant_contact

  # Cart
  get "/cart", to: "restaurant/cart#show", as: :restaurant_cart
  post "/cart/add", to: "restaurant/cart#add", as: :restaurant_cart_add
  patch "/cart/update", to: "restaurant/cart#update", as: :restaurant_cart_update
  delete "/cart/remove/:menu_item_id", to: "restaurant/cart#remove", as: :restaurant_cart_remove
  delete "/cart/clear", to: "restaurant/cart#clear", as: :restaurant_cart_clear

  # Orders
  resources :orders, only: [:new, :create], module: :restaurant
  get "/orders/:id/confirmation", to: "restaurant/orders#confirmation", as: :restaurant_order_confirmation
end

# Restaurant admin (under MilkAdmin)
namespace :milk_admin do
  resources :restaurants do
    resources :menu_categories, except: [:show]
    resources :menu_items, except: [:show]
    resources :testimonials, except: [:show]
    resources :hours, only: [:index, :edit, :update]
    resources :reservations, only: [:index, :update, :destroy]
    resources :orders, only: [:index, :update, :destroy]
  end
end
```

**Verify:** `bin/rails routes | grep restaurant` shows all routes.

---

### Task 1.3: Create Restaurant resolver middleware

**Objective:** Load the current restaurant from the URL slug on every request.

**Files:**
- Create: `app/controllers/concerns/restaurant_scoped.rb`

```ruby
module RestaurantScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_restaurant
    helper_method :current_restaurant
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find_by!(slug: params[:restaurant_slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Restaurant not found"
  end

  def current_restaurant
    @restaurant
  end
end
```

**Verify:** Any controller including this module loads the restaurant from the URL.

---

## Phase 2: Restaurant Models

### Task 2.1: Add restaurant_id to MenuCategory

**Objective:** Scope menu categories to a restaurant.

**Files:**
- Create: `db/migrate/YYYYMMDD_add_restaurant_id_to_menu_categories.rb`
- Create: `app/models/menu_category.rb`

**Migration:**
```ruby
class AddRestaurantIdToMenuCategories < ActiveRecord::Migration[8.0]
  def change
    add_reference :menu_categories, :restaurant, foreign_key: true, null: true
  end
end
```

**Model:**
```ruby
class MenuCategory < ApplicationRecord
  belongs_to :restaurant
  has_many :menu_items, dependent: :destroy

  scope :active, -> { where(active: true) }
  scope :sorted, -> { order(:sort_order) }

  validates :name, presence: true
end
```

---

### Task 2.2: Add restaurant_id to MenuItem

**Objective:** Scope menu items to a restaurant (through category).

**Files:**
- Create: `db/migrate/YYYYMMDD_add_restaurant_id_to_menu_items.rb`
- Create: `app/models/menu_item.rb`

**Migration:**
```ruby
class AddRestaurantIdToMenuItems < ActiveRecord::Migration[8.0]
  def change
    add_reference :menu_items, :restaurant, foreign_key: true, null: true
  end
end
```

**Model:**
```ruby
class MenuItem < ApplicationRecord
  belongs_to :menu_category
  belongs_to :restaurant
  has_many :order_items, dependent: :destroy

  scope :active, -> { where(active: true) }
  scope :featured, -> { where(featured: true) }

  validates :name, :price, presence: true
end
```

---

### Task 2.3: Create remaining restaurant models

**Objective:** Add Testimonial, Hour, Reservation, Order, OrderItem models.

**Files:**
- Create: `db/migrate/YYYYMMDD_create_restaurant_models.rb`
- Create: `app/models/testimonial.rb`
- Create: `app/models/hour.rb`
- Create: `app/models/reservation.rb`
- Create: `app/models/order.rb`
- Create: `app/models/order_item.rb`

**Migration (combined):**
```ruby
class CreateRestaurantModels < ActiveRecord::Migration[8.0]
  def change
    create_table :testimonials do |t|
      t.references :restaurant, foreign_key: true, null: false
      t.string :customer_name
      t.text :quote
      t.integer :stars, default: 5
      t.boolean :active, default: true
      t.boolean :featured, default: false
      t.timestamps
    end

    create_table :hours do |t|
      t.references :restaurant, foreign_key: true, null: false
      t.integer :day_of_week, null: false
      t.time :open_time
      t.time :close_time
      t.boolean :closed, default: false
      t.timestamps
    end

    create_table :reservations do |t|
      t.references :restaurant, foreign_key: true, null: false
      t.string :customer_name
      t.string :phone
      t.integer :party_size
      t.date :reservation_date
      t.time :reservation_time
      t.text :special_requests
      t.string :status, default: "pending"
      t.timestamps
    end

    create_table :orders do |t|
      t.references :restaurant, foreign_key: true, null: false
      t.string :customer_name
      t.string :phone
      t.time :pickup_time
      t.decimal :total, precision: 8, scale: 2
      t.string :status, default: "pending"
      t.timestamps
    end

    create_table :order_items do |t|
      t.references :order, foreign_key: true, null: false
      t.references :menu_item, foreign_key: true, null: false
      t.integer :quantity, default: 1
      t.decimal :price, precision: 8, scale: 2
      t.timestamps
    end
  end
end
```

**Models:**
```ruby
# testimonial.rb
class Testimonial < ApplicationRecord
  belongs_to :restaurant
  scope :active, -> { where(active: true) }
  scope :featured, -> { where(featured: true) }
  validates :customer_name, :quote, presence: true
end

# hour.rb
class Hour < ApplicationRecord
  belongs_to :restaurant
  scope :ordered, -> { order(:day_of_week) }

  DAYS = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].freeze

  def day_name
    DAYS[day_of_week] || "Unknown"
  end
end

# reservation.rb
class Reservation < ApplicationRecord
  belongs_to :restaurant
  validates :customer_name, :phone, :party_size, :reservation_date, :reservation_time, presence: true
  scope :pending, -> { where(status: "pending") }
end

# order.rb
class Order < ApplicationRecord
  belongs_to :restaurant
  has_many :order_items, dependent: :destroy
  validates :customer_name, :phone, :total, presence: true
  scope :pending, -> { where(status: "pending") }
end

# order_item.rb
class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :menu_item
  validates :quantity, :price, presence: true
end
```

**Verify:** `bin/rails db:migrate` succeeds, all models can be created in console.

---

## Phase 3: Public Controllers

### Task 3.1: Create restaurant pages controller

**Objective:** Handle homepage, about page for each restaurant.

**Files:**
- Create: `app/controllers/restaurant/pages_controller.rb`

```ruby
module Restaurant
  class PagesController < ApplicationController
    include RestaurantScoped

    def home
      @featured_items = @restaurant.menu_items.featured.active.includes(:menu_category).limit(6)
      @categories = @restaurant.menu_categories.active.sorted.limit(3)
      @testimonials = @restaurant.testimonials.active.featured.limit(3)
      @hours = @restaurant.hours.ordered
    end

    def about
    end
  end
end
```

---

### Task 3.2: Create restaurant menu controller

**Objective:** Display the full menu for each restaurant.

**Files:**
- Create: `app/controllers/restaurant/menu_controller.rb`

```ruby
module Restaurant
  class MenuController < ApplicationController
    include RestaurantScoped

    def index
      @categories = @restaurant.menu_categories.active.sorted.includes(:menu_items)
    end
  end
end
```

---

### Task 3.3: Create restaurant contact controller

**Objective:** Handle contact form for each restaurant.

**Files:**
- Create: `app/controllers/restaurant/contact_controller.rb`

```ruby
module Restaurant
  class ContactController < ApplicationController
    include RestaurantScoped

    def index
      @contact = Contact.new
      @hours = @restaurant.hours.ordered
    end
  end
end
```

---

### Task 3.4: Create restaurant cart controller

**Objective:** Handle cart operations (add, update, remove, clear).

**Files:**
- Create: `app/controllers/restaurant/cart_controller.rb`

```ruby
module Restaurant
  class CartController < ApplicationController
    include RestaurantScoped

    def show
      @cart = session[:cart] || {}
      @cart_items = build_cart_items
    end

    def add
      item_id = params[:menu_item_id].to_s
      session[:cart] ||= {}
      session[:cart][item_id] = (session[:cart][item_id] || 0) + 1
      redirect_back fallback_location: restaurant_menu_path(@restaurant.slug)
    end

    def update
      item_id = params[:menu_item_id].to_s
      quantity = params[:quantity].to_i
      session[:cart] ||= {}
      if quantity <= 0
        session[:cart].delete(item_id)
      else
        session[:cart][item_id] = quantity
      end
      redirect_to restaurant_cart_path(@restaurant.slug)
    end

    def remove
      session[:cart]&.delete(params[:menu_item_id].to_s)
      redirect_to restaurant_cart_path(@restaurant.slug)
    end

    def clear
      session[:cart] = {}
      redirect_to restaurant_cart_path(@restaurant.slug)
    end

    private

    def build_cart_items
      return [] if session[:cart].blank?
      item_ids = session[:cart].keys
      items = MenuItem.where(id: item_ids).index_by(&:id)
      session[:cart].map do |item_id, quantity|
        item = items[item_id.to_i]
        next unless item
        { item: item, quantity: quantity, subtotal: item.price * quantity }
      end.compact
    end
  end
end
```

---

### Task 3.5: Create restaurant orders controller

**Objective:** Handle order creation and confirmation.

**Files:**
- Create: `app/controllers/restaurant/orders_controller.rb`

```ruby
module Restaurant
  class OrdersController < ApplicationController
    include RestaurantScoped
    skip_before_action :verify_authenticity_token, only: [:create], if: -> { request.format.json? }

    def new
      @cart = session[:cart] || {}
      @cart_items = build_cart_items
      @order = Order.new
    end

    def create
      @order = @restaurant.orders.build(order_params)
      @cart = session[:cart] || {}
      @cart_items = build_cart_items

      @order.total = @cart_items.sum { |ci| ci[:subtotal] }

      if @order.save
        @cart_items.each do |ci|
          @order.order_items.create!(
            menu_item: ci[:item],
            quantity: ci[:quantity],
            price: ci[:item].price
          )
        end
        session[:cart] = {}
        redirect_to restaurant_order_confirmation_path(@restaurant.slug, @order)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def confirmation
      @order = @restaurant.orders.find(params[:id])
    end

    private

    def order_params
      params.require(:order).permit(:customer_name, :phone, :pickup_time)
    end

    def build_cart_items
      return [] if session[:cart].blank?
      item_ids = session[:cart].keys
      items = MenuItem.where(id: item_ids).index_by(&:id)
      session[:cart].map do |item_id, quantity|
        item = items[item_id.to_i]
        next unless item
        { item: item, quantity: quantity, subtotal: item.price * quantity }
      end.compact
    end
  end
end
```

---

## Phase 4: Views

### Task 4.1: Create restaurant layout

**Objective:** Base layout for restaurant pages that applies the restaurant's theme.

**Files:**
- Create: `app/views/layouts/restaurant.html.erb`

```erb
<!DOCTYPE html>
<html>
<head>
  <title><%= @restaurant.name %></title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="<%= @restaurant.tagline || @restaurant.name %>">
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>

  <link href="https://fonts.googleapis.com/css2?family=<%= @restaurant.font_display.gsub(' ', '+') %>&family=<%= @restaurant.font_body.gsub(' ', '+') %>:wght@400;600;700&display=swap" rel="stylesheet">
  <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet"/>

  <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
  <%= javascript_importmap_tags %>

  <style>
    :root {
      --primary: <%= @restaurant.primary_color %>;
      --accent: <%= @restaurant.accent_color %>;
      --dark: <%= @restaurant.dark_color %>;
      --font-display: '<%= @restaurant.font_display %>', cursive;
      --font-body: '<%= @restaurant.font_body %>', sans-serif;
    }
  </style>
</head>
<body class="font-body text-brown bg-cream min-h-screen">
  <%= render "restaurant/shared/navbar" %>
  <%= render "shared/flash_messages" %>
  <main>
    <%= yield %>
  </main>
  <%= render "restaurant/shared/footer" %>
</body>
</html>
```

**NOTE:** The `<style>` block with CSS variables is the ONE exception to the no-inline-styles rule — these are dynamic values from the database that set the restaurant's theme. Tailwind can't do this.

---

### Task 4.2: Create restaurant shared partials

**Objective:** Navbar and footer that adapt to each restaurant.

**Files:**
- Create: `app/views/restaurant/shared/_navbar.html.erb`
- Create: `app/views/restaurant/shared/_footer.html.erb`

Build these based on the El Mexicano navbar/footer pattern but make them read from `@restaurant` instead of hardcoded values.

---

### Task 4.3: Create restaurant page views

**Objective:** Homepage, menu, about, contact views.

**Files:**
- Create: `app/views/restaurant/pages/home.html.erb`
- Create: `app/views/restaurant/pages/about.html.erb`
- Create: `app/views/restaurant/menu/index.html.erb`
- Create: `app/views/restaurant/contact/index.html.erb`
- Create: `app/views/restaurant/cart/show.html.erb`
- Create: `app/views/restaurant/orders/new.html.erb`
- Create: `app/views/restaurant/orders/confirmation.html.erb`

These are adapted from El Mexicano's views but use `@restaurant` for data.

---

## Phase 5: Admin

### Task 5.1: Create restaurant admin controllers

**Objective:** Admin CRUD for restaurants and their content.

**Files:**
- Create: `app/controllers/milk_admin/restaurants_controller.rb`
- Create: `app/controllers/milk_admin/menu_categories_controller.rb`
- Create: `app/controllers/milk_admin/menu_items_controller.rb`
- Create: `app/controllers/milk_admin/testimonials_controller.rb`
- Create: `app/controllers/milk_admin/hours_controller.rb`
- Create: `app/controllers/milk_admin/orders_controller.rb`
- Create: `app/controllers/milk_admin/reservations_controller.rb`

Each controller follows the existing MilkAdmin pattern with `before_action :authenticate_milk_admin!`.

---

### Task 5.2: Create restaurant admin views

**Objective:** Admin dashboard for managing restaurants.

**Files:**
- Create: `app/views/milk_admin/restaurants/index.html.erb`
- Create: `app/views/milk_admin/restaurants/show.html.erb`
- Create: `app/views/milk_admin/restaurants/edit.html.erb`
- Create: `app/views/milk_admin/restaurants/_form.html.erb`
- Create: `app/views/milk_admin/menu_categories/` (index, new, edit, _form)
- Create: `app/views/milk_admin/menu_items/` (index, new, edit, _form)
- Create: `app/views/milk_admin/testimonials/` (index, new, edit, _form)
- Create: `app/views/milk_admin/hours/` (index, edit)
- Create: `app/views/milk_admin/orders/` (index)
- Create: `app/views/milk_admin/reservations/` (index)

---

### Task 5.3: Add restaurants link to admin dashboard

**Objective:** Make restaurants accessible from the admin sidebar.

**Files:**
- Modify: `app/views/milk_admin/dashboard.html.erb`

Add a "Restaurants" card/link to the dashboard overview.

---

## Phase 6: Seed Data

### Task 6.1: Create El Mexicano seed

**Objective:** Seed El Mexicano with all its data (menu, hours, testimonials).

**Files:**
- Create: `db/seeds/el_mexicano.rb`

This pulls the existing data from the El Mexicano app:
- Restaurant record (name, slug, theme, address, phone, etc.)
- 13 menu categories
- 78 menu items
- Hours (7 days)
- Testimonials
- Featured items

---

### Task 6.2: Create Italian Garden seed

**Objective:** Seed Italian Garden as a second restaurant tenant.

**Files:**
- Create: `db/seeds/italian_garden.rb`

Same structure as El Mexicano seed but with Italian Garden data.

---

## Phase 7: Assets

### Task 7.1: Copy restaurant images

**Objective:** Move food photos and illustrations into the portfolio app.

**Files:**
- Copy: El Mexicano images to `app/assets/images/restaurants/el-mexicano/`
- Copy: Italian Garden images to `app/assets/images/restaurants/italian-garden/`

Update view references to use the new paths.

---

## Verification Checklist

After implementation:
- [ ] `/el-mexicano` loads the El Mexicano homepage
- [ ] `/el-mexicano/menu` shows the full menu
- [ ] `/el-mexicano/about` shows the about page
- [ ] `/el-mexicano/contact` shows the contact form
- [ ] Cart add/remove/clear works
- [ ] Order creation works
- [ ] Admin can manage restaurants at `/milk_admin/restaurants`
- [ ] Admin can manage menu items per restaurant
- [ ] Existing portfolio pages (workbench, studio, lab) still work
- [ ] No routing conflicts
- [ ] `bin/rails test` passes (if tests exist)

---

## Future: Per-Restaurant Owner Auth

When paying clients need their own login:
1. Add `restaurant_id` to User model
2. Create `RestaurantOwner` Devise model scoped to restaurant
3. Add owner-facing admin at `/:restaurant_slug/admin`
4. Owners only see their own data

This is NOT needed for the demo platform — Mason manages everything through MilkAdmin.

---

## Migration from Standalone Apps

Once the multi-tenant version is working:
1. Export data from El Mexicano standalone app
2. Import into portfolio app's restaurants table
3. Kill the standalone Heroku app
4. Repeat for Italian Garden

Each restaurant saved = ~$7-10/mo in hosting costs eliminated.
