# FitTrack

Native iOS fitness app — one fast, beautiful app replacing MyFitnessPal + Strong/Hevy + a habit
tracker. Full architecture and rationale: [`PLAN.md`](PLAN.md).

**Status: Phase 1 complete** — local-only core (SwiftData, no backend/accounts yet). Phases 2–4
(sync/accounts, HealthKit/barcode/AI-estimate/widgets, polish+hardening) are not started.

## Repo layout

```
ios/          SwiftUI app — written here on Windows, built/run on Mac in Xcode
backend/      Node/Fastify API — runnable and testable here on Windows (Phase 2+)
docs/         Architecture, privacy, security-review docs
```

## Building on the Mac (do this first)

This code was written on Windows and has never been compiled — **the first Mac build is expected
to surface errors**. That's normal for Phase 1; report whatever Xcode shows and it'll get fixed.

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
invitations (fresh SwiftData store, ~146 seeded exercises). No sign-in — Phase 1 has no backend.

### Signing

`project.yml` ships `DEVELOPMENT_TEAM: ""`. In Xcode, go to the FitTrack target → **Signing &
Capabilities** and select your personal team so it can build to a simulator/device. Re-run
`xcodegen generate` after any `project.yml` edits — it will not clobber your Xcode-side signing
choice, which lives in a local user file, not `project.yml`.

## Manual smoke script (run after every phase)

1. **Log a meal in 2 taps:** Today → "+ Log lunch" → tap a recent/saved item → ring animates,
   sheet dismisses. (First run has no recents — use "Describe freeform" once to seed one.)
2. **Log a set in 1 tap:** Train → "Start empty workout" → "Add exercise" → tap a set's checkmark
   → rest-timer banner appears, haptic fires. Hit a heavier weight/more reps than before → PR badge.
3. **Kill network, log everything:** enable Airplane Mode. Log a meal, log a set, log water/weight
   — all should work identically (Phase 1 is 100% local; Phase 2+ adds an offline badge + sync).
4. **Finish a workout:** tap "Finish" → summary screen shows sets/volume/duration → Done returns
   to Train.
5. **Progress:** log a couple of weight entries and completed sets, then check Progress → Body
   (trend line appears after 2+ weigh-ins) and Strength (e1RM chart appears after 1+ completed set).

## Backend (Phase 2+, not yet built)

Runs and tests entirely on this Windows machine once implemented:
```
cd backend
npm install
npm test          # vitest
npm run dev        # against local Postgres (Docker)
```
