# Session Record — 2026-07-01

## CarUs — Alpha Progress

### Done (Code)

| # | Item | Details |
|---|---|---|
| 1 | Shop notification on booking | `shop_notified_at` column on BookingRequest. Manager dashboard shows green banner with count. Auto-marks as seen. |
| 2 | Digital Manual | Hardcoded fluids → real `ai_specs` JSON. Added AI summary, service suggestions, and tech notes sections. |
| 3 | Coupon on booking | `flash_alert_id` on BookingRequest. Confirm page shows shop's active deals, tap to apply. Discount in line items. |
| 4 | Customer history tab | Vehicle detail shows real bookings (date pills) + completed ServiceJobs + ServiceRecords. |
| 5 | Customer Lookup screen | Was hardcoded (Mason Roberts, Jane Doe). Now shows real customers + "Due This Week" from real bookings. |
| 6 | Vehicle Lookup fixes | Search bar now works (VIN/make/model). Year/make/model dropdowns are real selects. Scoped to shop + chat-looked-up vehicles. |
| 7 | Chat vehicles → Lookup | Made `car_owner` optional on Vehicle. `looked_up_by` now always updates. Tech lookup includes chat-created vehicles. |
| 8 | Login polish | Removed "Midas/SpeeDee" branding from customer login → "Vehicle Intelligence." Chrome autofill stays dark. Footer says "Powered by Rogue Media Lab." |
| 9 | HEALTHY badge | Dark frosted glass (`bg-black/60 backdrop-blur-sm`) — readable on any photo. |
| 10 | Manager booking edit | "Edit" button on each booking card. Manager can change services, date, time, notes, assigned tech. |
| 11 | Shop settings | New `settings` JSONB column on `car_us_shops`. Manager → Settings page with tax rate, supplies fee, travel fee (toggle + label + amount), max bookings per slot. |
| 12 | Real pricing | `PricingService` computes subtotal + supplies + travel + tax → full breakdown. Confirm + thank-you pages show line items. |
| 13 | Availability | Time slots check actual booking counts. Slots show: available / "1 spot left" (amber) / "Full" (grayed out, unclickable). |

### Database changes this session

- `car_us_booking_requests.shop_notified_at` (datetime)
- `car_us_booking_requests.flash_alert_id` (integer)
- `car_us_shops.settings` (jsonb, default {})
- `car_us_vehicles.car_owner_id` — made nullable (optional)

### Remaining Alpha

| # | Item | Type |
|---|---|---|
| 5 | Habibi onboarding — real techs, real vehicles | Setup |
| 6 | Dogfood the chat — real VIN lookups at work | Testing |

### Post-Alpha / Beta Roadmap

- Estimates system — manager creates estimate from booking, customer approves/declines
- Customer detail page — click customer → see vehicles, history, bookings
- Booking detail page — full info, not just summary card
- Past/completed bookings view
- Vehicle history from manager side
- Booking revenue stats on dashboard
- Dark theme for manager portal
- "Add Customer" from manager side
- Flash deal performance metrics
- Stripe subscriptions ($75 Basic / $150 Pro)
- Multi-tenant data isolation
- Email (confirmations, reminders)
- Tests
- Heroku deploy with CI gate

---

## Brooke & Maisy — Roadmap

Plan saved at: `~/Rogue-Media-Lab/Studio-Projects/RML-Brooke-Maisy/brooke-maisy/docs/plans/2026-07-01-next-phase-roadmap.md`

### Immediate (next session)

1. Merge `feature/design-presentation-builder` → main → deploy
2. Client-side presentation view
3. About content → `SiteSetting` or CMS model + admin edit
4. Services → `Service` model + admin CRUD + dynamic pages
5. Trade Network → `TradePartner` model + admin CRUD + dynamic page

### Future

6. Square API integration
7. AI Room Visualizer (Gemini 2.5 Flash)
8. Hermes read-only API
9. Email automation

---

## Demos / Credentials

| Role | Email | Shop |
|---|---|---|
| Customer | `jus18@gmail.com` | SpeeDee/Midas |
| Tech | `tech@carus.com` | SpeeDee/Midas |
| Manager | `mason@roguemedialab.com` | SpeeDee/Midas |
| Manager | `habibi@example.com` | Habibi Mobile |

Passwords: set during seeding (use forgot password if needed).