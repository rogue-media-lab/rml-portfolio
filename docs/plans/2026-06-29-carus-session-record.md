# CarUs Phase 4 — Customer + Technician Screens
# Session Record — 2026-06-29
# Branch: carus-phase4-customer

## How to Reset & Start Fresh

```bash
cd ~/Rogue-Media-Lab/Studio-Projects/RML-Portfolio/rml-portfolio
git checkout main
git branch -D carus-phase4-customer   # discard this branch
# OR
git checkout carus-phase4-customer    # pick up where we left off
unset DATABASE_URL
bin/rails db:drop db:create db:migrate
bin/rails runner "load 'db/seeds/carus_seed.rb'"
bin/dev
```

---

## Models Created (6)

### CarUs::Vehicle — car_us_vehicles
- car_owner:references (→ car_owners), vin:string:uniq, year:integer, make:string, model:string, trim:string, engine_size:string, transmission:string, mileage:integer
- belongs_to :car_owner
- has_many :service_records, :booking_requests, :concerns
- NHTSA vPIC VIN decoder (cached 30 days)
- Migration: 20260629033709

### CarUs::ServiceRecord — car_us_service_records
- vehicle:references (→ car_us_vehicles), service_date:date, mileage:integer, description:text, technician_name:string, cost:decimal
- belongs_to :vehicle
- Migration: 20260629040142

### CarUs::BookingRequest — car_us_booking_requests
- vehicle:references (→ car_us_vehicles), service_type:string, preferred_date:date, preferred_time:string, notes:text, status:string
- belongs_to :vehicle
- Migration: 20260629040155

### CarUs::Notification — car_us_notifications
- car_owner:references (→ car_owners), title:string, body:text, read:boolean, category:string
- belongs_to :car_owner
- Migration: 20260629112330

### CarUs::Concern — car_us_concerns
- vehicle:references (→ car_us_vehicles), title:string, description:text, severity:string, flagged_by:string
- belongs_to :vehicle
- Migration: 20260629112339

### CarOwner (updated)
- Added: has_many :vehicles, has_many :notifications

---

## Controllers (11)

| Controller | Actions | Layout |
|---|---|---|
| CarUs::VehiclesController | index, show, new, create | car_us/car_owner |
| CarUs::ProfilesController | show | car_us/car_owner |
| CarUs::ServiceRecordsController | index | car_us/car_owner |
| CarUs::BookingRequestsController | new, create | car_us/car_owner |
| CarUs::ManualsController | show | car_us/car_owner |
| CarUs::ConcernsController | new, create | car_us/car_owner |
| CarUs::NotificationsController | index | car_us/car_owner |
| CarUs::PagesController | home, welcome | car_us/car_owner |
| CarUs::RegistrationsController | (Devise overrides) | car_us/car_owner |
| CarUs::TechLookupsController | index, show, customer_lookup | car_us/technician |
| CarUs::TechProfilesController | show | car_us/technician |

---

## Routes Added (under scope "/carus")

```ruby
# Public
get "welcome", to: "car_us/pages#welcome", as: :carus_welcome

# Customer (authenticate :car_owner)
resource :profile, only: [:show], controller: "car_us/profiles"
resources :notifications, only: [:index], controller: "car_us/notifications"
resources :vehicles, only: [:index, :show, :new, :create] do
  resource :manual, only: [:show], controller: "car_us/manuals"
  resources :service_records, only: [:index], controller: "car_us/service_records"
  resources :booking_requests, only: [:new, :create], controller: "car_us/booking_requests"
  resources :concerns, only: [:new, :create], controller: "car_us/concerns"
end

# Technician (authenticate :technician)
resource :tech_profile, only: [:show], controller: "car_us/tech_profiles"
resources :tech_lookups, only: [:index, :show], controller: "car_us/tech_lookups"
get "customer_lookups", to: "car_us/tech_lookups#customer_lookup", as: :customer_lookups
```

---

## Views Created (17 files)

### Customer (13 screens)
| File | Paper Screen | Description |
|---|---|---|
| car_us/pages/home.html.erb | 1 | Splash hero + shop directory |
| car_owners/sessions/new.html.erb | 12 | Login — brand, email/password |
| car_owners/registrations/new.html.erb | 15 | Onboarding Step 1 — sign up form |
| car_us/pages/welcome.html.erb | 16 | Onboarding Step 3 — confirmed |
| car_us/vehicles/index.html.erb | 2 | My Garage — vehicle cards |
| car_us/vehicles/new.html.erb | 11 | Register Vehicle + VIN decode |
| car_us/vehicles/show.html.erb | 3 | Vehicle Detail — hero, mileage |
| car_us/service_records/index.html.erb | 9 | Service History — timeline |
| car_us/manuals/show.html.erb | 13 | Digital Manual — warning lights |
| car_us/booking_requests/new.html.erb | 14 | Book Service — date/time picker |
| car_us/notifications/index.html.erb | 4 | Alerts — notification cards |
| car_us/concerns/new.html.erb | 10 | Flag a Concern — form |
| car_us/profiles/show.html.erb | 7 | Customer Profile — stats/toggles |

### Technician (4 screens)
| File | Paper Screen | Description |
|---|---|---|
| car_us/tech_lookups/index.html.erb | 5 | Vehicle Lookup — year/make/model |
| car_us/tech_lookups/show.html.erb | 6 | Tech Spec Sheet — oil/tires/fluids |
| car_us/tech_lookups/customer_lookup.html.erb | 17 | Customer Lookup — search/recents |
| car_us/tech_profiles/show.html.erb | 8 | Tech Profile — stats/quick tools |

---

## Design Tokens (Tailwind — app/assets/tailwind/application.css)

```css
--color-carus-black: #0D0D0D;
--color-carus-panel: #141414;
--color-carus-field: #1A1A1A;
--color-carus-green: #0FB900;
--color-carus-border: #FFFFFF14;
--color-carus-text-muted: #FFFFFF4D;
--color-carus-text-dim: #FFFFFF33;
--font-montserrat: "Montserrat", sans-serif;
```

---

## Config Changes

- `config/initializers/devise.rb`: `config.scoped_views = true` (line 247)
- Devise scoped views at `app/views/car_owners/`

---

## Seed Data

- **Source**: `~/.hermes/data/vehicle_data.db` (SQLite, read-only export)
- **Export**: `db/seeds/data/vehicles.json` (55), `jobs.json` (86), `labor_times.json` (30), `job_parts.json` (10), `procedures.json` (14)
- **Seed script**: `db/seeds/carus_seed.rb`
- **Demo account**: `demo@carus.app` / `password123`
- **Result**: 48 vehicles + 85 service records under demo owner

---

## Design System

- Dark theme throughout — `bg-carus-black`, `#0FB900` green accent
- Montserrat font (Google Fonts, loaded via content_for :head)
- Mobile-first at 390px width (all Paper artboards are 390×844)
- Paper-accurate typography: 10/11/13/15/17/22/26/28/42px sizes
- Tab bars with SVG icons on every screen
- Consistent input styling: rounded-xl, bg-carus-field, subtle borders

---

## What's NOT Built Yet (for Waypoint-parity tech flow)

| Feature | Paper Screen | What It Needs |
|---|---|---|
| Oil Service Detail | 21 | Tech view with labor time, parts list, procedures — the core Wayland workflow |
| Front End Detail | 22 | Same pattern, different service category |
| Shop Owner Dashboard | 19 | Manager overview with "Due This Week", upcoming services report |
| Notification Preview | 18 | Single notification detail view |
| LaborTime model | — | Flat-rate labor times reference (30 entries exported, no model yet) |
| Parts/Procedures seeding | — | 10 parts + 14 procedures exported but not mapped to records |
| The Car's Voice | 20/20b | DEFERRED per plan doc Phase 8 |

### Key Waypoint Parity Gaps

The Waypoint bot does: VIN → vehicle info, job logging with parts + procedures + labor time, hours tracking, and **AI-powered contextual tips** (pain points, tool recommendations, difficulty warnings). CarUs tech side needs:

1. **LaborTime model** — seed the 30 flat-rate services into a reference table
2. **Oil Service Detail** (screen 21) — a job detail view showing labor time estimate, parts needed, step-by-step procedures
3. **Service logging flow** — tech looks up customer → selects service → sees parts/procedures/labor → logs completion with mileage
4. **Hours tracking** — the Waypoint bot tracks job time entries. CarUs could track technician hours per job as `CarUs::JobTimeEntry`

### AI Element (Waypoint Parity)

The tech side needs AI integration matching Waypoint's intelligence:

- **Contextual tips on spec sheets** — when a tech views a vehicle spec (screen 6), AI surfaces: pain points for that job, tool recommendations, difficulty level, common gotchas. Source: procedures table (14 entries) + hardcoded lookup table from plan doc §GAP 2
- **Related-service suggestions** — static map curated by Mason. E.g.: lower control arms done → suggest tire-wear + alignment check. Not an inference engine — a lookup table. Plan doc §GAP 2 Option B
- **Customer-facing summaries** — when a tech flags a concern or logs a service, AI generates plain-English explanation for the notification (no jargon). "Rear brake pads at 30% life" instead of "Pad thickness 4mm remaining"
- **API-first, local-ready** — use an API (OpenRouter/Claude) for the demo, but design the integration point so it can swap to a local model later. Store generated content in the DB so it works offline after initial generation
- **VIN decode** — already built (NHTSA vPIC API, server-side, cached 30 days)

**Architecture:** A `CarUs::AiService` concern/module that wraps API calls. All prompts are templates stored in the DB or YAML files (not hardcoded). Generation happens on-demand with DB caching — same spec sheet only gets generated once per vehicle.

---

# Session 2 — 2026-06-29 (evening)

## Booking Flow Fixes

- Added date picker (min=tomorrow) + 4 time radio slots (8AM/10AM/1PM/3PM) to booking Step 1
- Confirmation screen now shows selected date/time from params
- Fixed `NoMethodError` in `create` — controller now rebuilds `@selected_services` on validation failure
- Fixed model validation: `service_type` → `service_types` (matched DB column)
- Typos fixed in verify user action typo commit
- Added `thank_you` view — green checkmark, appointment summary, "Back to Garage" button
- Route: `get :thank_you` on booking_requests collection

## Manager Dashboard — Appointment Inbox

- Added "Upcoming Appointments" section to manager dashboard
- Query: `BookingRequest.joins(vehicle: :car_owner).where(car_owners: { shop_id: current_shop.id })`
- Shows customer name, vehicle, services, date/time, notes
- **Technician assignment** — migration added `technician_id` to `car_us_booking_requests`
- Assign dropdown on each booking, submits via PATCH to `manager/bookings#update`
- Route: `resources :bookings, only: [:update]` in manager namespace
- Scoped to manager's shop only

## Tech Views Cleanup

**Removed (dead code):**
- `oil_detail` — empty shell, route, controller action
- `front_end_detail` — empty shell, route, controller action
- `shop_dashboards` — empty controller + view + route + directory
- `tech_vehicles` — merged into tech_lookups (add-vehicle form + vehicle list)

**Kept (4 screens):**
- `/tech_lookups` — home base: assigned appointments + vehicle list + add vehicle
- `/tech_lookups/:id` — vehicle spec sheet + job history + log job
- `/conversations` — chat threads
- `/tech_profile` — tech profile with book hours + jobs done stats

**Shared tab bar:** `_tech_tab_bar.html.erb` — Lookup | Chat | Customers | Profile
Uses `request.path` for active-state highlighting. Replaced 7 inline tab bars across all tech views.

## ServiceJob + JobPart — Hours & Procedures

**Migrations:**
- `car_us_service_jobs` — vehicle_id, technician_id, description, book_hours(decimal), status, notes, completed_at
- `car_us_job_parts` — service_job_id, name, quantity(decimal 6,2), cost(decimal 8,2)
- Fixed quantity from integer → decimal for floats like 4.6 quarts

**Models:**
- `CarUs::ServiceJob` — belongs_to vehicle, technician; has_many job_parts
- `CarUs::JobPart` — belongs_to service_job
- Associations added to Technician (`has_many :service_jobs`) and Vehicle

**Controller:** `CarUs::ServiceJobsController` — create with:
- Auto-match hours from labor_times if blank (fuzzy match on description)
- Parts array saving (name, quantity, cost)
- Route: `POST /tech_lookups/:id/service_jobs`

**Vehicle show page (`tech_lookups/show`):**
- "Log Job" section — description field + hours field + procedure chip library (8 quick-pick buttons from labor_times)
- Parts fields (3 rows) — name, quantity (step=0.1), cost
- Job History section — lists all jobs with parts, per-job hours, running total
- 30 labor_times seeded from Waypoint data
- Profile stats show real data (book hours sum, jobs count)

## Editable Vehicle Specs

- **Stimulus controller:** `specs_editor_controller.js` — toggles hidden form on Edit button
- **Route:** `PATCH /tech_lookups/:id/update_specs`
- Edit button on each spec card (Engine Oil, Tires, Fluids, Torque & Plugs)
- Forms are stacked vertically with example placeholders
- Merges into `ai_specs` JSON column on vehicle

## Current State
- **Branch:** `carus-phase4-customer`
- **Directory:** `~/Rogue-Media-Lab/Studio-Projects/RML-Portfolio/rml-portfolio`
- **Server:** `unset DATABASE_URL && bin/dev`
- **Manager login:** `mason@roguemedialab.com`
- **Tech login:** `tech@carus.com`
- **Demo customer:** `jus18@gmail.com` (shop: SpeeDee/Midas, vehicle: 2020 Honda Accord)
