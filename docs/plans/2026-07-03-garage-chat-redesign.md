# Garage Chat Redesign — 2026-07-03

## Problem
After onboarding, the car goes mute. The garage is static data cards. No chat, no voice, no indication
that the AI knows the car. "To Oil Change: —" is a dead stat with no path to fix it.

## Design
The garage IS the conversation. Three zones:

1. **Car chips (top)** — horizontal scroll of 44px circular thumbnails + name labels.
   Active car gets green ring. "+" chip adds vehicle. Default state: no car selected,
   garage AI greets with overview.

2. **Chat area (middle)** — fills available space. Car messages left-aligned in dark
   gray (#141414) bubbles. User messages right-aligned in green (#0FB900). Active
   car avatar + name shown above chat when a car is selected.

3. **Input bar + info chips (bottom)** — "Reply to your Accord..." input pill with
   send button. Issue chips below chat show active topics (oil, front end, etc).

## Nav Bar Change
Replace "Deals" with "Chat" — Garage | Chat | Alerts | Profile.
Deals surface in context (car recommends relevant shop deals) or in Alerts.

## Personality Switching
Each car has its own personality from onboarding (JSONB on CarOwner.onboarding_messages).
Tapping a car chip switches the active car, avatar, conversation history, and AI voice.
The garage AI (no car selected) gives overview of all cars.

## Data Needs (future)
- Per-vehicle chat messages (new model or JSONB column)
- Oil change interval tracking (last service date + interval miles)
- AI integration for open-ended car chat (builds on existing OnboardingChatService)