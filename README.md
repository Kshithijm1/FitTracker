# FitTrack

Native iOS fitness app — one fast, beautiful app replacing MyFitnessPal + Strong/Hevy + a habit
tracker. Full architecture and rationale: [`PLAN.md`](PLAN.md).

**Status: Phases 1–5 complete.** Local-only core (SwiftData), backend accounts + sync
(Fastify/Drizzle/Postgres, Sign in with Apple + email/password, push/pull sync with
last-write-wins conflict resolution), integrations (HealthKit steps/sleep, barcode scanning,
AI freeform-meal estimate, Today rings widget, rest-timer Live Activity), and hardening
(Face ID app-lock, app-switcher privacy redaction, accessibility pass, security self-review).
Signing in is optional — every core feature still works fully offline; an account only adds
cross-device sync and server-side AI fallback.

**Phase 5 (2026-07):** first-run welcome/login + goal questionnaire that computes a full plan
(Mifflin-St Jeor calories, macros, water, steps, pace-clamped goal dates) and seeds goal-named
starter routines; Home page rebuilt (greeting, day/week/month progress with weight change,
calorie ring with training-earned calories in their own color, three user-swappable quick-log
tiles, ask-the-coach bar); AI coach with **on-device RAG memory** (`NLEmbedding` vectors in
SwiftData, cosine retrieval — free, private, unlimited) answering from your own data via the
on-device Foundation model (iOS 26+) or Claude on the backend; Train overhaul (set types
warmup/drop/failure, per-exercise tracking kinds incl. treadmill speed/incline/duration and
distance cardio, exercise reorder, muscle-group-filtered picker, configurable rest timer,
workout history + save-as-routine, per-exercise progress search, MET-based calorie burn,
equipment-photo → AI exercise suggestions with weight pre-fill); Nutrition overhaul (meal
sections, calorie day/week detail with previous weeks, 9 portion units, My Foods history,
recipe builder, AI recipe import from URL/caption, food-photo logging); full Profile (all
goals incl. sleep + goal date, weight/volume/distance units, AI memory controls).

Security posture: [`docs/SECURITY-REVIEW.md`](docs/SECURITY-REVIEW.md) (OWASP Mobile Top 10 +
API Top 10 self-review, checked against this codebase, not a template). Dependency scanning:
[`.github/dependabot.yml`](.github/dependabot.yml).

## Repo layout

```
ios/          SwiftUI app — written here on Windows, built/run on Mac in Xcode
backend/      Node/Fastify API — runnable and testable here on Windows
docs/         Deployment + security-review docs
```

## Building on the Mac (do this first)

This code was written on Windows and has never been compiled — **the first Mac build is expected
to surface errors**. Report whatever Xcode shows and it'll get fixed.

1. Copy or `git clone` this repo to the Mac.
2. Install Xcode 16+ (App Store) and [XcodeGen](https://github.com/yonaskolb/XcodeGen):
   ```
   brew install xcodegen
   ```
3. Generate the Xcode project (never commit the `.xcodeproj` — it's regenerated from
   `ios/project.yml`):
   ```
   cd ios
   xcodegen generate
   open FitTrack.xcodeproj
   ```
4. In Xcode: select the **FitTrack** scheme, a simulator (e.g. iPhone 16), and **Run** (⌘R).
5. Run tests with ⌘U (or `xcodebuild test -scheme FitTrack -destination 'platform=iOS Simulator,name=iPhone 16'`).

**Expected result:** app launches to the Today tab with all rings at zero and empty-state
invitations (fresh SwiftData store, ~146 seeded exercises). Sign-in is optional (Profile tab →
"Sign in to enable sync") — the backend must be running (see below) for it to succeed;
`BackendConfig.swift` points Debug builds at `http://localhost:3000`, which the Simulator (running
on the same Mac) can reach directly.

**Real-device-only features:** barcode scanning (VisionKit's `DataScannerViewController` isn't
supported in the Simulator) and Live Activities render correctly only on a physical device or a
Simulator running iOS 16.1+ with a compatible runtime — test the barcode flow on a real iPhone.

### Signing

`project.yml` ships `DEVELOPMENT_TEAM: ""`. In Xcode, go to the FitTrack target → **Signing &
Capabilities** and select your personal team so it can build to a simulator/device. Re-run
`xcodegen generate` after any `project.yml` edits — it will not clobber your Xcode-side signing
choice, which lives in a local user file, not `project.yml`.

## Manual smoke script (run after every phase)

1. **Log a meal in 2 taps:** Today → "+ Log lunch" → tap a recent/saved item → ring animates,
   sheet dismisses. (First run has no recents — use "Describe freeform" once to seed one.)
2. **Log a set in 1 tap:** Train → "Start empty workout" → "Add exercise" → tap a set's checkmark
   → rest-timer banner appears, haptic fires, and a Live Activity appears on the Lock
   Screen/Dynamic Island (real device). Hit a heavier weight/more reps than before → PR badge.
3. **Kill network, log everything:** enable Airplane Mode. Log a meal, log a set, log water/weight
   — all should work identically (local-only core; sync/remote search/AI-estimate are additive).
4. **Finish a workout:** tap "Finish" → summary screen shows sets/volume/duration → Done returns
   to Train.
5. **Progress:** log a couple of weight entries and completed sets, then check Progress → Body
   (trend line appears after 2+ weigh-ins) and Strength (e1RM chart appears after 1+ completed set).
6. **Sync:** with the backend running (below), Profile → "Sign in to enable sync" → create an
   account → log something → "Sync now". Kill the app, reinstall (simulating a second device with
   the same account), sign in again → the logged item should reappear after sync.
7. **HealthKit:** Profile → "Connect Apple Health" → accept the rationale screen → system prompt
   → grant access → Today's step/sleep rings populate from Health (real device with Health data).
8. **Barcode → OFF lookup:** Log-meal sheet → "+" → "Scan barcode" (real device) → scan any
   packaged food → product logs directly from Open Food Facts.
9. **Widget:** add the FitTrack widget to the Home Screen → shows the live calorie ring; log a
   meal in-app → widget updates within a few seconds (`WidgetCenter.reloadTimelines`).
10. **Face ID lock:** Profile → enable "Face ID app lock" → background the app (Home button/swipe)
    → app-switcher shows the FitTrack logo, not your data → reopen → Face ID/passcode prompt
    blocks content until authenticated.

## Backend (accounts, sync, AI meal estimate)

Runs and tests on any machine with Node 22+ and Postgres:
```
cd backend
npm install
docker compose up -d              # local Postgres on :5433 (or `brew install postgresql@17`
                                   # and run it on 5433 — no Docker required)
cp .env.example .env               # fill in JWT_ACCESS_SECRET (openssl rand -hex 32), etc.
                                    # ANTHROPIC_API_KEY is optional — without it, /v1/nutrition/estimate
                                    # and the /v1/ai/* routes return 503 and the iOS client degrades
                                    # gracefully (manual entry / on-device AI where available)
npm run db:migrate
npm run dev                        # API on :3000

cp .env.test.example .env.test     # separate DB (fittrack_test) so tests never touch dev data
docker exec backend-postgres-1 psql -U fittrack -d fittrack -c "CREATE DATABASE fittrack_test;"
npm run db:migrate:test
npm test                           # vitest — 34 tests, real Postgres, no mocks
```
Deploying to Fly.io + Neon: [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).
