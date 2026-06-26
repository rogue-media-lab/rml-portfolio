# CarUs — Portfolio Subproject Build Plan

**Date:** 2026-06-15
**Author:** Mason Roberts (Developer3027) w/ Wayland
**Status:** PLANNING — no build started
**Target repo:** RML-Portfolio/rml-portfolio (ONLY)
**Reference-only repos:** RML-Shop-Rewards/shop-rewards, Carus Paper file
**Branch to create:** `feature/carus-subproject`

---

## 1. Objective

Build **CarUs** — a two-sided automotive shop ↔ car-owner platform — as a **modular subproject inside the portfolio**, following the established Hermit Plus / restaurant multi-tenant pattern. Mounted under `/carus`. Self-contained so it can be extracted into a standalone app later.

CarUs demonstrates the app concept under the Rogue Media Lab portfolio umbrella. It is seeded from a one-time export of the local `vehicle_data.db` (the Wayland Discord bot's SQLite store) but has **no live connection** to Hermes, the laptop, or that database. The portfolio's own PostgreSQL is the system of record.

Functional target: **roughly** the technician-side capability of the Wayland Discord bot (VIN decode, vehicles, jobs, parts, procedures, hours) re-expressed as a web app. "Roughly" because: no live Discord, no live local-DB link, and voice/TTS deferred.

---

## 2. Locked Decisions (resolved with user 2026-06-15)

| # | Decision |
|---|----------|
| 1 | **Migrate IN** as a portfolio subproject. Modular, extractable later. |
| 2 | **Two roles, two layouts, one Carus design.** Car Owner (User) + Technician. Shop Owner dashboard folds into the admin/manager side. |
| 3 | **Self-contained Postgres** in the portfolio. One-time seed export from `vehicle_data.db`. NO live link to laptop/Hermes/SQLite. |
| 4 | **Branch in portfolio repo only.** All other projects reference-only. |
| 5 | **Architecture A — fully namespaced.** `CarUs::` models, `CarOwner` + `Technician` Devise scopes, `/carus` route scope. |
| 6 | **VIN decode IS in scope** — server-side NHTSA vPIC API call from Rails. |
| 7 | **Voice capture + TTS deferred** to a future phase; will be Discord-independent when built. |
| 8 | **Product name: CarUs.** URL slug: `/carus`. shop-rewards repo is structural reference only. |

---

## 3. Reference Inventory (confirmed by inspection)

### 3a. shop-rewards (Rails 8, Ruby 3.3.7 — same stack as portfolio)
Existing models to lift/adapt: `User`, `AdminUser`, `Shop`, `Profile`, `Service`, `Redemption`, `FlashAlert`.
Existing routes: Devise users + admin_users; customer routes (coupons, services, rewards); `manager` namespace (dashboard, flash_alerts, customers+search, redemptions).
Verdict: light, clean structure. Salvage routing shape and manager portal; rebuild models under `CarUs::` namespace.

### 3b. Carus Paper file — 23 artboards, 390×844 mobile, Montserrat
**Car Owner surface:**
- 1 Splash · 12 Login · 15/16 Onboarding
- 2 My Garage · 3 Vehicle Detail · 11 Register Vehicle
- 4 Notifications · 18 Notification Preview
- 7 Customer Profile · 9 Service History · 13 Digital Manual
- 10 Flag a Concern · 14 Book Service
- 20 / 20b The Car's Voice  *(DEFERRED — voice/TTS phase)*

**Technician surface:**
- 5 Tech Lookup · 6 Tech Spec Sheet · 17 Tech Customer Lookup
- 8 Tech Profile · 21 Oil Service Detail · 22 Front End Detail

**Shop Owner / Admin surface:**
- 19 Shop Owner Dashboard *(folds into manager/admin namespace)*

---

## 4. Architecture

### 4a. Namespacing (Architecture A)
- **Models:** `CarUs::Vehicle`, `CarUs::Job`, `CarUs::Part`, `CarUs::Procedure`, `CarUs::ServiceRecord`, `CarUs::Concern`, `CarUs::Notification`, `CarUs::Shop`, etc. Table prefix `carus_`.
- **Auth:** two dedicated Devise models — `CarOwner` and `Technician` — fully separate from the portfolio's existing `User` / `MilkAdmin`. (Avoids the collision: portfolio already has `User` + `MilkAdmin`; shop-rewards also had `User` + `AdminUser`.)
- **Controllers:** `CarUs::` module → `app/controllers/car_us/...`
- **Views:** `app/views/car_us/...` with **own layouts** — `car_us/car_owner` and `car_us/technician`. NEVER touch `application.html.erb`. (Per established subproject rule.)
- **Routes:** `scope "/carus", module: "car_us", as: "carus" do ... end` with `authenticated :car_owner` and `authenticated :technician` blocks routing to the correct layout.

### 4b. Why this is extractable later
All CarUs code lives under `car_us/` namespaces (models, controllers, views, layouts) + `carus_` tables. Pulling it into a standalone app = copy the namespaced tree, drop the prefix, regenerate Devise. No entanglement with portfolio core models.

### 4c. Data model (Rails-native, seeded from vehicle_data.db export)
Core entities mirrored from Wayland: `Vehicle` (VIN, year/make/model, owner ref), `Job` (labor time, status, dates), `Part`, `Procedure`, `ServiceRecord`, plus web-native `CarOwner`, `Technician`, `Concern` (flag-a-concern), `Notification`, `BookingRequest`.

---

## 5. Phased Plan (≈1 week+ horizon)

> Each phase ends with a green boot + CI-gated commit on `feature/carus-subproject`. **Never push to Heroku directly — CI is the gate.** Run `gitnexus_impact` before editing existing portfolio symbols; `gitnexus_detect_changes` before each commit. Re-run `npx gitnexus analyze` after commits.

### Phase 0 — Branch & Safety (do first, ~15 min)
- Commit or stash the pending `static_pages/index.html.erb` change so the branch starts clean.
- `git checkout -b feature/carus-subproject`
- Confirm `bin/dev` boots clean on the new branch before ANY edit.

### Phase 1 — Foundation & Namespacing
- Generate `CarOwner` + `Technician` Devise models (registrations scoped appropriately).
- Generate namespaced models with `carus_` table prefix + migrations (Vehicle, Job, Part, Procedure, ServiceRecord, Concern, Notification, Shop, BookingRequest).
- Set up `scope "/carus"` routing skeleton + two empty layouts (`car_owner`, `technician`).
- `db:migrate` against portfolio Postgres. Boot check. Commit.

### Phase 2 — Seed Export from vehicle_data.db
- Write a **one-time** export script (read-only against the local SQLite) → fixtures/seed JSON committed to the portfolio.
- Build `db/seeds/carus_seed.rb` to load it. Idempotent.
- Verify seeded data renders in Rails console. Commit. (After this, the SQLite link is severed forever.)

### Phase 3 — Auth flow + role routing (Paper screens 1, 12, 15, 16)
- Splash → Login → Onboarding. Post-login role detection → correct layout/dashboard.
- Implement per `rails-conventions` (Tailwind only, no inline styles, `button_to` for DELETE).
- Paper-first: implement screen-by-screen matching the Carus design. Commit per screen group.

### Phase 4 — Car Owner surface (screens 2, 3, 11, 7, 9, 13, 4, 18, 10, 14)
- My Garage → Vehicle Detail → Register Vehicle (with **VIN decode** via NHTSA vPIC).
- Customer Profile, Service History, Digital Manual.
- Notifications + preview. Flag a Concern. Book Service.

### Phase 5 — Technician surface (screens 5, 6, 17, 8, 21, 22)
- Tech Lookup / Customer Lookup / Spec Sheet. Tech Profile.
- Job detail views (Oil Service, Front End) — the Wayland-parity core: labor time, parts, procedures, hours.

### Phase 6 — Shop Owner / Admin (screen 19)
- Shop Owner Dashboard folded into manager/admin namespace (adapt shop-rewards manager portal).

### Phase 7 — Portfolio integration
- Add CarUs tile/landing to the portfolio Studio page (showcase entry, same as Zuke/Hermit Plus).
- Final boot + CI pass. PR to main. CI is the gate.

### Phase 8 — DEFERRED (future, not this build)
- "The Car's Voice" (screens 20/20b) — voice capture + TTS, Discord-independent.

---

## 6. Open Questions / Risks
- **Seed export schema:** need to inspect `vehicle_data.db` table shapes when Phase 2 begins (not yet examined — out of scope for this plan doc).
- **Mobile-only design:** all 23 artboards are 390×844. Confirm whether desktop/responsive treatment is wanted or mobile-frame-only showcase.
- **VIN decode rate limits:** NHTSA vPIC is free/no-key but should be cached per-VIN to avoid repeat calls.
- **Devise multi-model registration:** confirm whether Technicians self-register or are admin-provisioned.

---

## 7. Hard Rules (carried from memory/profile)
- Surgical changes only. Verify before acting.
- Tailwind ONLY — no inline styles. `button_to` for DELETE in Turbo.
- Subproject gets its OWN nav/footer/layout partials — NEVER modify `application.html.erb`.
- Versioned files, never overwrite (logo_v2, etc.).
- Load `rails-conventions` skill before any view work.
- Never push to Heroku. GitHub CI is the gate.
- Run gitnexus impact/detect_changes around edits to existing portfolio symbols.

---

## v1.1 Addendum (2026-06-15) — Purpose Reconciliation

Appended after reconciling Mason's product-purpose statement against §1–7 above.
Additive only — nothing above is rewritten. This addendum is authoritative where it
overlaps the original draft.

### Purpose statement (canonical, locked)
CarUs is a personalized vehicle-maintenance app with a two-sided value model:
- **Car owner:** an effective, personalized way to stay current on car repairs —
  per-vehicle maintenance info + full service history, plus easy access to generic
  online coupons (barcode-based) usable at participating shops.
- **Participating shop:** push alerts to customers, pull reports on upcoming services
  owed by their customers — i.e. a way to keep bays full.
- **Technician:** pull specific information on a specific car.
- **Landing page:** sells the concept publicly, with a login path into the app.

### GAP 1 — Coupons (was missing entirely) — **CONFIRMED (Q1)**
- Add model `CarUs::Coupon`: `code`, `barcode` (rendered), `shop_id` (nullable —
  generic coupons are not shop-locked), `expires_at`, `description`.
- Owner-side **barcode display in v1** — owner opens a coupon, sees a scannable
  barcode in-bay. Render server-side with `rqrcode` (QR) / `barby` (1D barcode);
  no live external coupon feed for the demo — Mason sources the numbers initially.
- Shop-manager coupon CRUD is **modeled but deferred** (admin/manager surface owns
  it later; not in the demo build).

### GAP 2 — Technician follow-up — **OPTION B (Q2)**
- Add a **"Today's Bay Schedule"** morning-feed screen for the technician: who is
  coming in today, tap a customer to open that vehicle's history.
- Related-service suggestions come from a **hardcoded lookup table**, NOT an
  inference engine. Demo-appropriate: e.g. lower control arms done → suggest tire-wear
  + alignment check after the brake job. Static map, curated by Mason.

### GAP 3 — Shop-owner login — **CONFIRMED: no separate shop-owner login (Q3)**
- **No** dedicated shop-owner Devise scope. The shop owner acts through the existing
  admin/manager surface (folds into the manager side per §3).
- A **manager provisions technician accounts** under their shop (resolves original
  open-question #4 → shop-provisioned; techs do NOT self-register).

### GAP 4 — Shop "upcoming services" report (purpose-statement requirement)
- Elevate to a first-class manager-side screen: a report of services coming due
  across that shop's customers (the "keep bays full" engine). Backed by
  `CarUs::Job` history + maintenance intervals. Demo: read-only report view.

### Models touched by this addendum
- NEW: `CarUs::Coupon` (belongs_to :shop, optional: true)
- EXISTING (from §4, unchanged): `CarUs::Vehicle`, `CarUs::Job`, `CarUs::Part`,
  `CarUs::Procedure`
- Roles unchanged: `CarOwner` + `Technician` Devise scopes; shop owner via manager surface.

### Status
PLANNING → **SPEC LOCKED.** Ready to create branch `feature/carus-subproject` in
`RML-Portfolio/rml-portfolio` and begin Phase 1. No build started yet.
