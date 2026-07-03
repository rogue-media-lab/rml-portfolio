# Session Record — 2026-07-02

## CarUs — Vision, Landing Page, Onboarding Chat

### Vision Refined

CarUs is not a marketplace. It's a **vehicle relationship app.** The car is the protagonist. AI knows the driver, the car, the maintenance history. The car talks. The shop fulfills.

Two textures, one engine:
- **Habibi** (mobile, husband+wife) — nurture relationships, lightweight messaging for regulars
- **Midas** (7 bays, staffed) — structured booking, no open chat, clean handoff

Pricing: consumer $4.99/month single, $8.99 family. Shop from $75/month. Both sides pay. AI isn't free.

### Landing Page — Rewritten

- Dark theme (`bg-carus-black`, Montserrat) matching the app
- Hero: "Your car is talking. Are you listening?"
- Three steps: Your Car Knows → You Approve → Shop Fulfills
- Features: Maintenance Awareness, Service History, Digital Manual, Easy Booking
- Consumer card: $4.99/mo. Shop card: "from $75/mo"
- "Powered by Rogue Media Lab" footer

### Login Screens — Two-Column Desktop

- Form constrained to 420px, info panel on the right
- Car Owner: "Your car is talking. Are you listening?" + feature bullets
- Technician: "Customers arrive ready. You just execute." + shop features
- Mobile: form-only, centered, unchanged

### Onboarding Expanded

**Phase 1 — Structured form:**
- Sign Up: added Street Address + Work Address fields
- Vehicle Registration: VIN moved to top, required, green-accented. Photo required.
- Migration: work_address, occupation, work_days, commute_type on CarOwner

**Phase 2 — AI Chat:**
- Processing screen: pulsing car icon, 3-second auto-redirect to chat
- 3 canned questions (no AI cost to generate):
  1. "Tell me about your car. How long have you had it?"
  2. "What's a typical week look like?"
  3. "If your car had a voice..."
- AI responds conversationally via qwen/qwen3.7-plus (Net::HTTP, credentials fallback)
- Messages stored in JSONB column on CarOwner (not session cookie — overflow at 4KB)

### Bugs Fixed

1. **API key** — OnboardingChatService was only reading ENV, missing `Rails.application.credentials`
2. **Cookie overflow** — conversation history was in session, blew past 4KB. Moved to `car_owners.onboarding_messages` JSONB column
3. **Turbo Stream failure** — 20-35 second AI responses broke Turbo Stream real-time updates. Replaced with waiting-page pattern:
   - Submit → save message instantly → spawn AI in background thread
   - Redirect to `/onboarding/waiting?q=N` (auto-refreshes every 2 seconds)
   - When AI done → redirect to chat with next question
4. **Stuck state on refresh** — chat action now auto-advances question index based on answered count in DB

### Design Decisions

- **Canned questions vs AI-generated:** Mason chose canned. Same data quality, zero token cost for question generation. AI only pays to generate RESPONSES.
- **Two-phase onboarding:** Structured form first (address, VIN, photo), then AI chat for personality. Not everything needs to be conversational.
- **Vehicle personality inference:** Don't ask "what's your car's personality." Ask about color, condition, usage, life stage. The personality emerges from the details. Mason's Honda example: faded maroon, manual, dash intact, suspension loose, short commute → "loyal old dog" voice.

### What's Still Open

- Vehicle relationship engine — AI doesn't track personal mileage progression or compute "due soon" from service history yet
- Habibi onboarding — real tech, real vehicles, full flow test
- Production deployment — Heroku configured but never deployed
- Merge to main — 9 commits on `carus-phase4-customer` ahead of main