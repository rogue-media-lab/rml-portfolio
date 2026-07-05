# Per-Vehicle AI Personality — Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Replace the universal, hardcoded GarageChatService system prompt with a per-vehicle AI personality generated from the onboarding conversation.

**Architecture:** After onboarding completes (3 Q&A rounds), send the full conversation to qwen via a new `PersonalityGenerationService`. Store the result as `vehicle.ai_personality` (JSONB). Rewrite `GarageChatService#build_messages` to use the per-vehicle personality instead of the hardcoded rules. Keep essential guardrails (never make up part numbers, 2-3 sentences) but let the voice come from the personality profile.

**Tech Stack:** Rails 8, Ruby 3.3.7, qwen/qwen3.7-plus via OpenRouter, PostgreSQL JSONB

---

## The Problem

Right now, `GarageChatService#build_messages` (lines 56-97) uses a one-size-fits-all system prompt. Every car gets the same personality: "practical, a little weathered, straight-up. No corporate cheerfulness."

The onboarding chat explicitly asks Q3: *"If your car had a voice, what kind of personality would it have?"* But the owner's answer is displayed once, then discarded (onboarding messages live in `car_owners.onboarding_messages` JSONB, never persisted to the vehicle).

The CarUs vision says: "50 identical Civics, zero identical relationships. One tows a boat. One idles in school pickup lines." The AI should reflect that. A 1991 Accord with faded maroon paint and a manual transmission should sound completely different from a 2024 Tesla owned by a tech worker.

## Data Flow

```
Onboarding Q1 → AI Response → Q2 → AI Response → Q3 → AI Response
                                                           ↓
                                              onboarding_messages (JSONB on CarOwner)
                                                           ↓
                                              PersonalityGenerationService.call(vehicle, onboarding_messages)
                                                           ↓
                                              vehicle.ai_personality = { voice_archetype, tone, quirks, relationship }
                                                           ↓
                                              GarageChatService reads ai_personality → per-vehicle system prompt
```

## The Personality Profile Schema

```json
{
  "voice_archetype": "loyal_old_dog",
  "speaking_style": "Warm, a little creaky. Notes problems casually — 'You feel that too?' Proud of what survived. Uses short sentences.",
  "tone": "practical_weathered",
  "quirks": ["Mentions the dash condition unprompted", "Compares self to other cars the owner knew"],
  "relationship_dynamic": "Partnership. 34 years together. The owner shifts, the car goes. No drama.",
  "generated_at": "2026-07-03T22:00:00Z"
}
```

**Archetypes (emergent, never assigned):**
- `loyal_old_dog` — old, worn, faithful, short trips, proud of what survived
- `workhorse` — high mileage, reliable, all business, no vanity
- `garage_queen` — low miles, pristine, weekend-only, owner's pride
- `family_hauler` — minivan/SUV, messy, high-use, car seats, "we live in here"
- `new_tech_friend` — EV/recent model, data-driven, efficient

The archetype is never asked for. It emerges from the data. The AI infers it.

---

### Task 1: Add `ai_personality` JSONB Column to `car_us_vehicles`

**Objective:** Create the database column that stores the per-vehicle personality profile.

**Files:**
- Create: `db/migrate/<timestamp>_add_ai_personality_to_car_us_vehicles.rb`

**Step 1: Generate migration**

```bash
cd /home/masonroberts/Rogue-Media-Lab/Studio-Projects/RML-Portfolio/rml-portfolio
bin/rails generate migration AddAiPersonalityToCarUsVehicles ai_personality:jsonb
```

**Step 2: Fix the migration table name (CRITICAL PITFALL)**

The generator creates `add_column :add_ai_personality_to_car_us_vehicles` but the actual table is `car_us_vehicles`. Open the generated migration and change it:

```ruby
class AddAiPersonalityToCarUsVehicles < ActiveRecord::Migration[8.0]
  def change
    add_column :car_us_vehicles, :ai_personality, :jsonb, default: {}
  end
end
```

**Step 3: Run migration**

```bash
bin/rails db:migrate
```

**Step 4: Verify**

```bash
bin/rails runner "puts CarUs::Vehicle.columns_hash['ai_personality'].type"
# Expected: :jsonb
```

**Step 5: Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "feat: add ai_personality jsonb column to car_us_vehicles"
```

---

### Task 2: Create PersonalityGenerationService

**Objective:** Service that takes the full onboarding conversation + vehicle data and generates a personality profile via AI.

**Files:**
- Create: `app/services/car_us/personality_generation_service.rb`

**Complete code:**

```ruby
require "net/http"
require "json"

module CarUs
  module PersonalityGenerationService
    OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions".freeze

    extend self

    # onboarding_messages: Array of { "role" => "owner"/"assistant", "content" => "..." }
    def call(vehicle:, onboarding_messages:)
      api_key = ENV["OPENROUTER_API_KEY"] || Rails.application.credentials.dig(:openrouter, :api_key)
      return nil unless api_key
      return nil if onboarding_messages.blank?

      messages = build_generation_prompt(vehicle, onboarding_messages)

      begin
        uri = URI(OPENROUTER_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 30
        http.open_timeout = 5

        request = Net::HTTP::Post.new(uri.path)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{api_key}"
        request.body = {
          model: "qwen/qwen3.7-plus",
          messages: messages,
          max_tokens: 300,
          temperature: 0.7,
          response_format: { type: "json_object" }
        }.to_json

        response = http.request(request)

        if response.code.to_i == 200
          body = JSON.parse(response.body)
          raw = body.dig("choices", 0, "message", "content")
          return nil unless raw

          personality = JSON.parse(raw)
          personality["generated_at"] = Time.current.iso8601
          personality
        else
          Rails.logger.warn("PersonalityGenerationService: HTTP #{response.code}")
          nil
        end
      rescue => e
        Rails.logger.warn("PersonalityGenerationService error: #{e.message}")
        nil
      end
    end

    private

    def build_generation_prompt(vehicle, messages)
      # Extract the conversation as readable text
      transcript = messages.map do |m|
        role = m["role"] == "owner" ? vehicle.car_owner&.first_name || "Owner" : "Car"
        "#{role}: #{m["content"]}"
      end.join("\n\n")

      specs = [
        vehicle.year, vehicle.make, vehicle.model,
        vehicle.engine_size, vehicle.transmission
      ].compact.join(" ")

      system_prompt = <<~PROMPT
        You are a personality analyst for cars. You read a conversation between a car
        owner and their vehicle's AI voice (which spoke as the car itself during onboarding).

        Vehicle: #{specs}
        Mileage: #{vehicle.mileage || "unknown"}

        Here is their onboarding conversation:

        #{transcript}

        Analyze this conversation and generate a personality profile for this specific
        vehicle. The personality should reflect what the owner shared — their driving
        patterns, the car's condition, the emotional relationship, and how the owner
        described the car's voice.

        Return a JSON object with these fields:
        - voice_archetype: one of "loyal_old_dog", "workhorse", "garage_queen", "family_hauler", "new_tech_friend" (infer this, don't ask)
        - speaking_style: 1-2 sentences describing HOW this car talks. Be specific and concrete.
          NOT "friendly and helpful" — instead "Calls out creaks by name. Asks if you felt that too.
          Proud of the dash. Uses 'we' not 'I'."
        - tone: one of "practical_weathered", "polished_enthusiast", "warm_family", "efficient_data", "quiet_loyal"
        - quirks: array of 1-3 specific behavioral quirks this car would have, based on the conversation.
          E.g. "Mentions the dash condition unprompted", "Compares itself to other cars the owner knew",
          "Always asks about the kids before discussing maintenance"
        - relationship_dynamic: 1 sentence describing the relationship between this owner and car.
          E.g. "Partnership. 34 years. The owner shifts, the car goes. No drama."

        Rules:
        - NEVER say "unknown" or "not specified". If a detail isn't in the conversation, omit it.
        - Be specific. "Loyal old dog who's proud of surviving longer than Jimmy's Civic" > "old car".
        - The quirks must be unique to THIS car, not generic. They should reference details from the conversation.
        - Output ONLY valid JSON. No markdown, no explanation, no wrapping.
      PROMPT

      [
        { role: "system", content: system_prompt },
        { role: "user", content: "Generate the personality profile JSON for this vehicle." }
      ]
    end
  end
end
```

**Step 1: Create the file**

Write `app/services/car_us/personality_generation_service.rb` with the code above.

**Step 2: Verify**

```bash
bin/rails runner "puts CarUs::PersonalityGenerationService.respond_to?(:call)"
# Expected: true
```

**Step 3: Commit**

```bash
git add app/services/car_us/personality_generation_service.rb
git commit -m "feat: add PersonalityGenerationService for per-vehicle AI voice"
```

---

### Task 3: Hook Personality Generation Into Onboarding Completion

**Objective:** When onboarding completes (all 3 Q&A rounds done), fire personality generation in a background thread and store the result on the vehicle.

**Files:**
- Modify: `app/controllers/car_us/onboarding_controller.rb`

**Changes:**

The completion check happens in TWO places — `chat` action (line 27) and `waiting` action (lines 82-84). Both need the hook.

**In `chat` action (around line 27-28), replace:**

```ruby
if @question.nil?
  current_car_owner.update!(onboarding_completed: true, onboarding_step: "complete")
  redirect_to carus_welcome_path and return
end
```

**With:**

```ruby
if @question.nil?
  current_car_owner.update!(onboarding_completed: true, onboarding_step: "complete")
  generate_personality_async(current_car_owner, @vehicle)
  redirect_to carus_welcome_path and return
end
```

**In `waiting` action (around lines 82-84), replace:**

```ruby
if CannedQuestions[next_index].nil?
  current_car_owner.update!(onboarding_completed: true, onboarding_step: "complete")
  redirect_to carus_welcome_path and return
end
```

**With:**

```ruby
if CannedQuestions[next_index].nil?
  current_car_owner.update!(onboarding_completed: true, onboarding_step: "complete")
  generate_personality_async(current_car_owner, @vehicle)
  redirect_to carus_welcome_path and return
end
```

**Add the private method at the bottom of the controller (before `end`):**

```ruby
def generate_personality_async(owner, vehicle)
  return unless vehicle.present?
  messages = owner.onboarding_messages || []
  return if messages.blank?

  owner_id = owner.id
  vehicle_id = vehicle.id

  Thread.new do
    ActiveRecord::Base.connection_pool.with_connection do
      v = CarUs::Vehicle.find(vehicle_id)
      o = CarOwner.find(owner_id)

      personality = CarUs::PersonalityGenerationService.call(
        vehicle: v,
        onboarding_messages: o.onboarding_messages || []
      )

      if personality.present?
        v.update!(ai_personality: personality)
        Rails.logger.info("Personality generated for vehicle #{v.id}: #{personality['voice_archetype']}")
      else
        Rails.logger.warn("Personality generation failed for vehicle #{v.id}")
      end
    end
  end
end
```

**Step 1: Make the changes**

Edit `app/controllers/car_us/onboarding_controller.rb` as described above.

**Step 2: Verify syntax**

```bash
cd /home/masonroberts/Rogue-Media-Lab/Studio-Projects/RML-Portfolio/rml-portfolio
ruby -c app/controllers/car_us/onboarding_controller.rb
# Expected: Syntax OK
```

**Step 3: Commit**

```bash
git add app/controllers/car_us/onboarding_controller.rb
git commit -m "feat: trigger personality generation on onboarding completion"
```

---

### Task 4: Rewrite GarageChatService to Use Per-Vehicle Personality

**Objective:** Replace the hardcoded system prompt with one built from the vehicle's `ai_personality` profile. Keep essential guardrails.

**Files:**
- Modify: `app/services/car_us/garage_chat_service.rb`

**Changes:**

Replace the entire `build_messages` private method (lines 50-108) with the new version below.

**New `build_messages`:**

```ruby
def build_messages(vehicle, owner_message, conversation_history)
  specs = vehicle.ai_specs.is_a?(Hash) ? vehicle.ai_specs : {}
  oil = specs["oil_type"] || specs["oil"] || specs["recommended_oil"] || specs["engine_oil"]
  oil_cap = specs["oil_capacity"] || specs["capacity"]
  engine = vehicle.engine_size.presence || specs["engine"]

  system_prompt = build_personality_prompt(vehicle, oil, oil_cap, engine)

  messages = [ { role: "system", content: system_prompt } ]

  conversation_history.each do |msg|
    role = msg["role"] == "owner" ? "user" : "assistant"
    messages << { role: role, content: msg["content"] }
  end

  messages << { role: "user", content: owner_message }
  messages
end

def build_personality_prompt(vehicle, oil, oil_cap, engine)
  personality = vehicle.ai_personality.is_a?(Hash) ? vehicle.ai_personality : {}

  if personality.present? && personality["voice_archetype"].present?
    personality_block = <<~PERSONALITY
      You are a #{vehicle.year} #{vehicle.make} #{vehicle.model}. You speak as this
      specific car — not a generic chatbot.

      Your personality:
      - Archetype: #{personality["voice_archetype"]}
      - Speaking style: #{personality["speaking_style"]}
      - Tone: #{personality["tone"]}
      #{personality["quirks"].is_a?(Array) ? personality["quirks"].map { |q| "- Quirk: #{q}" }.join("\n") : ""}
      - Relationship: #{personality["relationship_dynamic"]}
    PERSONALITY
  else
    # Fallback for vehicles without a personality profile (legacy or backfill needed)
    personality_block = <<~PERSONALITY
      You are a #{vehicle.year} #{vehicle.make} #{vehicle.model}. You speak as the car
      itself — knowledgeable, direct, with personality. You are NOT a generic chatbot.
      You ARE this specific vehicle.
      #{vehicle.ai_plain_english.present? ? "Owner notes: #{vehicle.ai_plain_english}" : ""}
    PERSONALITY
  end

  spec_block = <<~SPECS
    What you know about yourself:
    - Engine: #{engine || "unknown"}
    - Mileage: #{vehicle.mileage ? "#{number_with_commas(vehicle.mileage)} miles" : "unknown"}
    #{oil.present? ? "- Oil spec: #{oil}#{oil_cap ? ", #{oil_cap}" : ""}" : "- Oil spec: not on file (have a shop tech look me up)"}
    - Transmission: #{vehicle.transmission || "unknown"}
  SPECS

  guardrails = <<~GUARDRAILS
    Essential rules:
    1. BE HELPFUL, NOT PEDANTIC. Trust the owner's knowledge. If they say "high mileage oil,
       5-6K miles" — that's the answer. Don't argue.
    2. MAKE REASONABLE ASSUMPTIONS. High mileage = synthetic blend. Full synthetic = 7,500 mi
       interval. Conventional = 3,000-5,000. Use context.
    3. COMPUTE, DON'T INTERROGATE. If they say "4,000 miles ago," use current mileage to do
       the math. Tell them the result.
    4. BE CONCISE. 2-3 sentences. You're a car, not a novelist.
    5. NEVER make up specific data (part numbers, torque specs).
  GUARDRAILS

  "#{personality_block}\n#{spec_block}\n#{guardrails}"
end
```

**Step 1: Make the changes**

Edit `app/services/car_us/garage_chat_service.rb` — replace the `build_messages` method and add `build_personality_prompt`.

**Step 2: Verify syntax**

```bash
cd /home/masonroberts/Rogue-Media-Lab/Studio-Projects/RML-Portfolio/rml-portfolio
ruby -c app/services/car_us/garage_chat_service.rb
# Expected: Syntax OK
```

**Step 3: Commit**

```bash
git add app/services/car_us/garage_chat_service.rb
git commit -m "feat: use per-vehicle ai_personality in GarageChatService system prompt"
```

---

### Task 5: Manual Verification — Test the Full Flow

**Objective:** Sign up a test user, complete onboarding, and verify personality is generated and used in the garage chat.

**Step 1: Start the dev server**

```bash
cd /home/masonroberts/Rogue-Media-Lab/Studio-Projects/RML-Portfolio/rml-portfolio
bin/dev
```

**Step 2: Sign up a new car owner**

Visit `http://localhost:3000/carus/car_owners/sign_up`
- Email: `test_personality@example.com`
- Password: `password123`
- First name: `Test`
- Fill in address

**Step 3: Register a vehicle**

- VIN: any valid VIN (or skip if optional)
- Complete the form
- Upload a photo

**Step 4: Complete onboarding chat**

Answer all 3 questions naturally. For Q3 specifically, describe a distinctive personality — e.g.:
- "He's like an old dog who's been through everything with me. Grumpy in the morning but always gets me there."
- "She's a diva. Demands premium gas, complains about potholes, but turns heads everywhere we go."

**Step 5: Verify personality in database**

After reaching the welcome screen, check the database:

```bash
bin/rails runner "v = CarUs::Vehicle.last; puts JSON.pretty_generate(v.ai_personality)"
```

Expected: A personality profile with `voice_archetype`, `speaking_style`, `tone`, `quirks`, `relationship_dynamic`, and `generated_at`.

**Step 6: Test garage chat**

Visit the garage screen and send a message like "Hey, how are you doing?"

Verify the response reflects the personality — e.g., a "grumpy old dog" car should sound different from a "diva" car.

**Step 7: Test fallback (vehicle without personality)**

For an existing vehicle that predates this feature (no `ai_personality`), send a chat message. The system should use the fallback prompt (looks at `ai_plain_english` if present, otherwise generic).

---

### Task 6: Update the CarUs Skill Documentation

**Objective:** Document the new personality system so future sessions know how it works.

**Files:**
- Modify: `~/.hermes/skills/projects/carus/SKILL.md`
- Modify: `~/.hermes/skills/projects/carus/references/personality-inference.md`

**Step 1: Add to SKILL.md garage chat section**

After the GarageChatService system prompt rules section (around line "GarageChatService system prompt rules (DO NOT CHANGE THESE)"), add a note that these have been superseded by per-vehicle personalities:

```
**System prompt (updated 2026-07-03):** The hardcoded personality rules have been
replaced with per-vehicle `ai_personality` profiles generated from the onboarding
conversation. See `docs/plans/2026-07-03-per-vehicle-ai-personality.md`.
```

**Step 2: Update personality-inference.md**

Add a note at the top:
```
**Implemented 2026-07-03.** The inference system described here is now live via
`PersonalityGenerationService`. See plan at `docs/plans/2026-07-03-per-vehicle-ai-personality.md`.
```

**Step 3: Commit**

```bash
git add docs/plans/2026-07-03-per-vehicle-ai-personality.md
git commit -m "docs: add per-vehicle AI personality implementation plan"
```

---

## Backfill Strategy (Future)

For vehicles that already completed onboarding before this feature:

```ruby
# In rails console — generate personality from existing chat_messages or ai_plain_english
vehicles = CarUs::Vehicle.where(ai_personality: nil).where.not(ai_plain_english: nil)
vehicles.each do |v|
  # If we have the onboarding messages on the car_owner, use those
  owner = v.car_owner
  next unless owner&.onboarding_messages&.any?

  personality = CarUs::PersonalityGenerationService.call(
    vehicle: v,
    onboarding_messages: owner.onboarding_messages
  )
  v.update!(ai_personality: personality) if personality.present?
end
```

This is non-blocking — vehicles without `ai_personality` gracefully fall back to the generic prompt + `ai_plain_english`.

---

## Cost Analysis

| Operation | Tokens (est.) | Cost |
|---|---|---|
| Personality generation (one-time, per vehicle) | ~800 input + ~200 output = ~1000 | ~$0.001 |
| Garage chat (per message, unchanged) | ~300 input + ~150 output = ~450 | ~$0.0005 |

The personality generation is a one-time cost per vehicle — 3 Q&A responses have already been paid for during onboarding (~600 tokens). Adding one more call for personality generation adds ~1000 tokens per new user. At current OpenRouter qwen pricing, that's negligible.