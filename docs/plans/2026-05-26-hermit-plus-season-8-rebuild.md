# Hermit Plus Season 8 — Rails Rebuild Plan

**Date:** 2026-05-26
**Project:** RML-Portfolio /hermit-plus sub-project
**Source Reference:** /home/masonroberts/projects/hermit-test/ (React + Express demo)
**Scope:** Convert React demo into functional Rails 8 sub-project. Season 8 only.

---

## Executive Summary

The existing /hermit-plus landing page is a static marketing page. This plan converts the React demo app into a functional Rails experience: users click "Season 8" on the landing page and enter the Hermit Plus app — a Netflix-style browser for Hermitcraft Season 8 content. Free user accounts unlock favorites, watchlists, and progress tracking. All data is sourced via YouTube Data API v3 with admin oversight.

---

## Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| App nested under `/hermit-plus/*` | Keeps sub-project isolated; landing page remains at `/hermit-plus` |
| YouTube API v3 for thumbnails/URLs | Fresh data, no stale JSON. Quota: 10,000 units/day (free tier) |
| Monthly thumbnail URL health check | YouTube thumbnail URLs can expire/change. Cron job validates. |
| Crews as a model, not hardcoded | Season 8 groups (Boat'em, Big Eye, Swamp, Goats) are organic — model allows future seasons |
| Manual admin approval for videos | API fetches suggestions; admin confirms episode #, season, hermit assignment |
| User accounts via existing Devise | Portfolio already has User model. Extend with hermit-plus profile data. |

---

## Data Model Changes

### Hermit (existing — additions)
```ruby
# New columns via migration
add_column :hermits, :from, :string           # "Michigan, USA"
add_column :hermits, :skin_url, :string       # Minecraft skin image URL
add_column :hermits, :face_url, :string       # Face/avatar image URL
add_column :hermits, :alias_image_url, :string # Banner text image URL
add_column :hermits, :info2, :text            # Second bio paragraph
add_column :hermits, :slug, :string           # URL-friendly alias
add_index :hermits, :slug, unique: true
```

### HermitVideo (existing — no schema changes needed)
Already has: `youtube_video_id`, `thumbnail_url`, `title`, `season`, `episode`, `hermit_id`.

### HermitCrew (new model)
```ruby
# Represents organic groups from Season 8
HermitCrew
  name:string        # "Boat'em Crew", "Big Eye Crew", "The Swamp", "The Goats"
  slug:string        # URL-friendly
  description:text   # "Grian, Mumbo, Scar, Impulse, and Pearl..."
  image_url:string   # Crew image (e.g. boatem_crew.png)
  season:integer     # 8 (for future-proofing)
  created_at, updated_at
```

### HermitCrewMembership (new join model)
```ruby
HermitCrewMembership
  hermit_crew_id:bigint
  hermit_id:bigint
```

### HermitAppearance (new join model)
```ruby
# Tracks which hermits appear in which videos (collaborations)
HermitAppearance
  hermit_video_id:bigint
  hermit_id:bigint
```

### UserHermitProfile (new model)
```ruby
# Extends User with hermit-plus specific data
UserHermitProfile
  user_id:bigint
  waitlist_status:string   # "pending", "approved", "declined"
  favorite_hermit_id:bigint
  notifications_enabled:boolean, default: true
```

### Favorite (new model)
```ruby
Favorite
  user_id:bigint
  hermit_video_id:bigint
  created_at
```

### WatchProgress (new model)
```ruby
WatchProgress
  user_id:bigint
  hermit_video_id:bigint
  progress_seconds:integer
  completed:boolean, default: false
  last_watched_at:datetime
```

---

## Route Structure

```ruby
# config/routes.rb

# Landing page (existing)
get "hermit-plus", to: "hermit_plus#landing", as: :hermits

# App entry — Season 8
scope "/hermit-plus" do
  get "/season/8", to: "hermit_seasons#home", as: :hermit_plus_home

  # Hermit roster and profiles
  get "/hermits", to: "hermit_roster#index", as: :hermit_roster
  get "/hermits/:slug", to: "hermit_roster#show", as: :hermit_profile

  # Video browsing
  get "/videos/:id", to: "hermit_videos#show", as: :hermit_video
  get "/watch/:id", to: "hermit_videos#watch", as: :hermit_watch

  # Crews / specials
  get "/crews", to: "hermit_crews#index", as: :hermit_crews
  get "/crews/:slug", to: "hermit_crews#show", as: :hermit_crew

  # User features (require authentication)
  authenticate :user do
    get "/favorites", to: "hermit_favorites#index", as: :hermit_favorites
    post "/favorites/:video_id", to: "hermit_favorites#create"
    delete "/favorites/:video_id", to: "hermit_favorites#destroy"
    patch "/progress/:video_id", to: "hermit_progress#update"
  end
end
```

---

## YouTube API Integration

### Service Object: `YoutubeService`
```ruby
# app/services/youtube_service.rb
class YoutubeService
  API_KEY = ENV["YOUTUBE_API_KEY"]
  BASE_URL = "https://www.googleapis.com/youtube/v3"

  def self.search_channel_videos(channel_id, max_results: 50)
    # Returns array of video hashes: { video_id, title, description, thumbnail_url, published_at }
  end

  def self.video_details(video_ids)
    # Batch fetch video details (max 50 IDs per call)
  end

  def self.validate_thumbnail_url(url)
    # HEAD request to check if thumbnail still returns 200
  end
end
```

### Background Job: `ThumbnailHealthCheckJob`
```ruby
# app/jobs/thumbnail_health_check_job.rb
class ThumbnailHealthCheckJob < ApplicationJob
  def perform
    HermitVideo.where(season: 8).find_each do |video|
      unless YoutubeService.validate_thumbnail_url(video.thumbnail_url)
        # Fetch fresh thumbnail from API and update
      end
    end
  end
end
```

### Cron Schedule
```yaml
# Monthly thumbnail health check
thumbnail_health_check:
  cron: "0 2 1 * *"  # 2 AM on the 1st of every month
  class: "ThumbnailHealthCheckJob"
```

### Admin Tool: Fetch from YouTube
```
MilkAdmin > Hermit Videos > "Fetch from YouTube"
- Input: YouTube channel URL or channel ID
- Action: Service fetches recent uploads, presents as suggestions
- Admin selects videos, assigns episode numbers, confirms save
```

---

## Phase Breakdown (Session-Sized Tasks)

### PHASE 1: Foundation & Data Models
**Goal:** Update schema, create new models, run migrations.

**Tasks:**
1. Generate migration: Add `from`, `skin_url`, `face_url`, `alias_image_url`, `info2`, `slug` to hermits
2. Generate model: HermitCrew (name, slug, description, image_url, season)
3. Generate model: HermitCrewMembership (hermit_crew_id, hermit_id)
4. Generate model: HermitAppearance (hermit_video_id, hermit_id)
5. Generate model: UserHermitProfile (user_id, waitlist_status, favorite_hermit_id, notifications_enabled)
6. Generate model: Favorite (user_id, hermit_video_id)
7. Generate model: WatchProgress (user_id, hermit_video_id, progress_seconds, completed, last_watched_at)
8. Add model associations and validations
9. Add slug generation to Hermit and HermitCrew (friendly_id or custom)
10. Run migrations and verify schema

**Deliverable:** All models created, associations tested in rails console.

---

### PHASE 2: YouTube API Service & Seeding
**Goal:** Build the YouTube service, seed initial data from React JSON structure.

**Tasks:**
1. Create `app/services/youtube_service.rb` with search and video_details methods
2. Add `YOUTUBE_API_KEY` to `.env` and document in README
3. Create `app/jobs/thumbnail_health_check_job.rb`
4. Create seed file: `db/seeds/hermit_plus_season_8.rb`
   - Seed hermits from React JSON structure (names, aliases, socials, etc.)
   - Use placeholder/stale thumbnail URLs initially
   - Seed crews: Boat'em Crew, Big Eye Crew, The Swamp, The Goats
   - Assign hermits to crews via memberships
5. Create seed file for sample videos (first 1-2 episodes per hermit from React JSON)
6. Test YouTube service in console: fetch real data for one channel
7. Build admin "Fetch from YouTube" suggestion UI (MilkAdmin)

**Deliverable:** `rails db:seed` populates Season 8 hermits, crews, and sample videos. YouTube service tested.

---

### PHASE 3: Public Controllers & Routes
**Goal:** Wire up all public-facing routes and controllers.

**Tasks:**
1. Create `HermitSeasonsController#home` — app entry point
2. Create `HermitRosterController#index` — hermit grid
3. Create `HermitRosterController#show` — hermit profile page
4. Create `HermitVideosController#show` — video detail page
5. Create `HermitVideosController#watch` — embedded player page
6. Create `HermitCrewsController#index` and `#show`
7. Update `config/routes.rb` with all new routes
8. Create `app/views/layouts/hermit_plus.html.erb` — app layout (nav + footer)
9. Update landing page "Season 8" link to point to `hermit_plus_home_path`

**Deliverable:** All routes respond with basic HTML. Layout renders correctly.

---

### PHASE 4: Views & UI (React → Rails Conversion)
**Goal:** Convert React component designs into Rails/Tailwind views.

**Tasks:**
1. **Home Page** (`hermit_seasons/home.html.erb`)
   - Banner slider (hermit banners carousel — Stimulus + Swiper or custom)
   - Crews/Specials section (4 crew cards)
   - Episode grid: "First Episode from every Hermit — Season 8"
   - Netflix-style hover effects on video cards

2. **Hermit Roster** (`hermit_roster/index.html.erb`)
   - Grid of hermit face cards (from React playerCard)
   - Filter by crew (dropdown or tabs)
   - Link to profile page

3. **Hermit Profile** (`hermit_roster/show.html.erb`)
   - Two-column layout (from React hermits/index.jsx)
   - Left: alias banner, name, subs, location, quote, bio
   - Right: social links, skin image, action buttons (Videos, Fan Art)
   - List of hermit's Season 8 episodes below

4. **Video Detail** (`hermit_videos/show.html.erb`)
   - Background thumbnail with dark fade overlay
   - Play button → watch page
   - Info button → hermit profile
   - Description, subtitle
   - Cast row: hermit face icons who appear in this video

5. **Watch Page** (`hermit_videos/watch.html.erb`)
   - Full-screen embedded YouTube iframe
   - Minimal chrome, back button

6. **Crews Index** (`hermit_crews/index.html.erb`)
   - Grid of crew cards with image + description

7. **Crew Show** (`hermit_crews/show.html.erb`)
   - Crew info + grid of member hermits + their episodes

**Deliverable:** All pages render with correct layout, data, and styling.

---

### PHASE 5: User Accounts & Features
**Goal:** Free user signup, favorites, watchlist, progress.

**Tasks:**
1. Extend existing User model (portfolio already has Devise User)
2. Create `UserHermitProfilesController` for profile management
3. Create `HermitFavoritesController` (index, create, destroy)
4. Create `HermitProgressController` (update watch progress)
5. Add "Add to Favorites" button on video detail page
6. Add "My Favorites" page (authenticated route)
7. Add watch progress tracking (Stimulus controller posts progress)
8. Update navbar to show user avatar / login state
9. Waitlist flow: on signup, create UserHermitProfile with status "pending"

**Deliverable:** Users can sign up, favorite videos, view favorites list.

---

### PHASE 6: Polish, Admin & Integration
**Goal:** Connect landing page, finalize nav, admin tools, QA.

**Tasks:**
1. Update landing page "Season 8" link → `hermit_plus_home_path`
2. Update `_hermits_nav.html.erb` with app navigation links
   - Home, Hermits, Crews, Favorites (if logged in)
3. Update `_hermits_footer.html.erb` with app links
4. MilkAdmin: Add HermitCrew CRUD
5. MilkAdmin: Add "Fetch from YouTube" button on hermit videos dashboard
6. MilkAdmin: Show thumbnail health status on video list
7. Add meta tags for all public pages (SEO)
8. Mobile responsive pass on all views
9. Add Turbo Frame navigation for smooth page transitions within app

**Deliverable:** Fully integrated sub-project. Landing page → App flow works.

---

## Asset Inventory (from React Project)

| Asset | Location in React | Rails Destination |
|-------|-------------------|-------------------|
| Hermit skins | `src/images/*_skin.png` | `app/assets/images/hermits/skins/` |
| Hermit faces | `src/images/*-face.png` | `app/assets/images/hermits/faces/` |
| Crew images | `src/images/boatem_crew.png`, etc. | `app/assets/images/hermits/crews/` |
| HermitPlusLogo | `src/images/HermitPlusLogo.png` | Already on S3 |
| Backgrounds | `public/images/home-background-green.png` | `app/assets/images/hermits/` |
| Character cards | S3 (mumboCard.png, etc.) | Keep on S3 |

**Note:** Many React images are stale or low-res. YouTube API avatars/banners should be primary source. Local assets are fallbacks.

---

## YouTube API Quota Math

| Operation | Quota Cost | Frequency |
|-----------|-----------|-----------|
| search.list (channel videos) | 100 units | Per hermit channel, ~1x/week for new episodes |
| videos.list (details) | 1 unit per video | Batch 50 at a time |
| thumbnail HEAD check | 0 units (HTTP) | Monthly health job |

**Daily budget:** 10,000 units
**Season 8 has ~26 hermits.** Weekly fetch all channels: 26 × 100 = 2,600 units. Well within budget.

---

## Open Questions / Future Considerations

1. **Fan Art:** React has a "Fan Art" button on hermit profiles. Is this user-uploaded content, or links to external galleries? Defer to Phase 2.
2. **Donations:** React has a Donate page. Is this needed for the Rails version? Currently not in scope.
3. **Season 9+:** Architecture supports multiple seasons via `season` column. Season 8 is hardcoded in routes for this sub-project.
4. **Real-time features:** Action Cable for "now watching" or chat? Defer to Phase 2.

---

## Success Criteria

- [ ] Clicking "Season 8" on landing page enters the Hermit Plus app
- [ ] Home page shows banner slider, crew cards, and episode grid
- [ ] Every hermit from Season 8 has a profile page with bio, socials, and episodes
- [ ] Video detail pages show correct thumbnails, descriptions, and cast
- [ ] Watch page embeds YouTube player correctly
- [ ] Users can create free accounts and favorite videos
- [ ] Admin can add new videos via YouTube API fetch tool
- [ ] Monthly thumbnail health check runs automatically
- [ ] All pages are mobile-responsive
- [ ] App feels like a standalone experience (custom nav, footer, layout)
