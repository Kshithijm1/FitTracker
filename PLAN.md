# FitTrack — Native iOS Fitness App: Architecture & Build Plan

## Context

Greenfield build in an empty directory (`C:\Users\kshit\Desktop\AppCodes\FitTrack`). The goal: one fast, beautiful iOS app replacing MyFitnessPal + Strong/Hevy + a habit tracker for a solo, health-conscious user. The governing constraint is **logging speed** — every core action (set, meal, water, weight) in 1–3 taps. Secondary hard requirements: hand-designed visual quality, offline-first with real accounts/sync, and fintech-grade security posture.

**Environment reality:** development happens on this Windows machine; the user has a Mac for building/running the iOS app in Xcode. The Node backend is fully runnable and testable here on Windows. Swift code is written Xcode-ready but compiled/verified on the Mac.

---

## 1. Tech Stack (decisions + tradeoffs)

### iOS Client
- **SwiftUI, Swift 6, iOS 18.0 minimum** (covers all mainstream late-2025/2026 devices; unlocks mature SwiftData, Swift Charts, `@Observable`, TipKit).
- **SwiftData** for local persistence — chosen over Core Data for far less boilerplate; over GRDB for first-party support. All logging writes locally first, always.
- **Swift Charts** for all graphs. **HealthKit** (steps/sleep read), **WidgetKit + ActivityKit** (rest-timer Live Activity, Today rings widget), **VisionKit/AVFoundation** for barcode scanning.
- **Zero third-party SwiftPM dependencies** in Phase 1–2 (security/dependency-hygiene win; everything needed is first-party).
- Project generation via **XcodeGen** (`project.yml` committed; user runs `xcodegen generate` on the Mac). Fallback: manual "create project, add folders" instructions in README.

### Backend
- **Node.js 22 + TypeScript, Fastify, Drizzle ORM, PostgreSQL, Zod** validation on every route.
- *Tradeoff vs Vapor (Swift):* Vapor gives one-language consistency, but Node/TS wins on auth ecosystem maturity (`jose` for JWT + Sign-in-with-Apple token verification, `argon2`, `@fastify/rate-limit` are battle-tested), managed-hosting happy paths, and dev velocity for a solo project. Drizzle emits parameterized queries by construction — SQL injection is structurally eliminated.
- **Hosting:** Fly.io or Railway for the API + **Neon** (managed Postgres, encryption at rest, branching for staging). Secrets via host's secret manager, never in code.
- **AI freeform-meal estimation:** a backend endpoint (`POST /v1/nutrition/estimate`) calling **Claude Haiku** with a structured-output prompt → `{calories, protein, carbs, fat, confidence}`. The Anthropic key lives only server-side.

### Nutrition data
- **Open Food Facts** (free, no key, best-in-class **barcode** + branded coverage) + **USDA FoodData Central** (free API key, authoritative generic/whole foods). Search merges: local cache → recents/frequents → OFF + FDC in parallel. Results cached into local `FoodItem` store so repeat searches are instant and offline.
- *Tradeoff:* a commercial API (Nutritionix/Edamam) has better restaurant coverage but costs $$$ monthly; for a solo user, OFF+FDC+AI-estimate covers ~95% of real logging, and the freeform estimator is the escape hatch for the rest.

---

## 2. Data Model

Client (SwiftData) and server (Postgres/Drizzle) share the same logical schema. All IDs are **client-generated UUIDs** (required for offline-first). All syncable records carry `updatedAt`, `deletedAt` (tombstone), `dirty` flag (client-only).

```
User          id, email?, appleUserID?, displayName, unit prefs (lb/kg), goals →
Goals         calorieTarget, proteinG, carbsG, fatG, waterML, stepTarget, weightGoal

— Training —
Exercise      id, name, muscleGroups[], equipment, isCustom, archivedAt
              (seeded with ~150 built-ins from a bundled JSON; user customs on top)
Routine       id, name, notes, position
RoutineItem   routineID → exerciseID, position, targetSets, targetReps
Workout       id, startedAt, finishedAt?, routineID?, notes   (finishedAt nil = in progress)
WorkoutItem   workoutID → exerciseID, position
SetEntry      workoutItemID, index, weightKG, reps, rpe?, isWarmup, completedAt
PersonalRecord  exerciseID, kind (weight|reps|volume|e1RM), value, setEntryID, achievedAt
              (derived + cached; recomputed on set save)

— Body —
WeightEntry        id, date, weightKG          (trend = 7-day EMA computed in app)
MeasurementEntry   id, date, site (waist|chest|arm|thigh|hip|…), valueCM
ProgressPhoto      id, date, localFileURL      (encrypted at rest via iOS file protection;
                                                NOT synced in v1 — documented)

— Nutrition —
FoodItem      id, name, brand?, source (usda|off|custom|estimate), barcode?,
              per100g {kcal,protein,carbs,fat}, servings[{label, grams}], lastUsedAt, useCount
SavedMeal     id, name ("My usual breakfast")
SavedMealItem savedMealID → foodItemID, quantityG
FoodLog       id, date, slot (breakfast|lunch|dinner|snack), foodItemID,
              quantityG, macroSnapshot {kcal,p,c,f}   ← snapshot so later food edits
                                                        don't rewrite history

— Habits —
WaterEntry    id, date, amountML
SleepEntry    id, date, minutes, source (manual|healthkit)
StepsCache    date, steps, source (healthkit|manual)   (device-local, not synced)

— Sync/Auth (server) —
AuthSession   id, userID, refreshTokenHash (SHA-256), familyID (rotation lineage),
              deviceName, expiresAt, revokedAt
ChangeCursor  per-user monotonic sync cursor
```

**Conflict resolution (documented rule): per-record last-write-wins on `updatedAt`,** with tombstones beating updates at equal timestamps. Realistic for a single-user-few-devices app; no field-level merging complexity.

---

## 3. Information Architecture & Key Flows

**Tabs:** `Today · Train · Nutrition · Progress · Profile` — but 90% of use is Today, which embeds quick-add for everything.

### Today screen
```
┌──────────────────────────────┐
│  Thursday, Jul 3      [◐ FT] │   ← date + tiny profile/streak
│                              │
│   ◔ 1,430 kcal left          │   ← calorie ring, macros as 3 thin bars
│   P 92g · C 140g · F 38g     │      underneath (remaining)
│                              │
│  ○ Water 3/8   ○ Steps 6.2k  │   ← habit rings row, tap water = +1 glass
│  ○ Sleep 7h12  ○ Move ✓      │      (single tap logs; long-press = custom)
│                              │
│  ┌────────────────────────┐  │
│  │ + Log lunch            │  │   ← context-aware by time of day;
│  │   [🍳 usual] [🔍] [barcode]│      one tap opens straight into recents
│  └────────────────────────┘  │
│  ┌────────────────────────┐  │
│  │ ▶ Continue workout      │  │   ← only if workout in progress;
│  │   Push Day · 4 sets in  │  │      else "Start workout" w/ last routine
│  └────────────────────────┘  │
└──────────────────────────────┘
```
Renders **entirely from local data before any network call**. Empty state (day 1): rings at zero with one-line invitations, not blank panels.

### Log-a-meal flow (target: 2 taps for a repeat meal)
```
Today ──tap "+ Log lunch"──▶ Log sheet (opens on RECENTS)
  ┌ Recents/Frequents grid ┐   tap item → logged with last portion, sheet
  │ [Chicken bowl] [Oats…] │   dismisses w/ ring animation.  DONE (2 taps)
  │ [My usual breakfast]   │
  ├ 🔍 search field (top)  ┤   type → local results instantly, remote merge in
  │                        │   tap result → logged at default portion; portion
  ├ [barcode] [✎ describe] ┤   stepper appears inline for 3s (adjust w/o nav)
  └────────────────────────┘
  [✎ describe] = freeform: "2 eggs and toast" → AI estimate w/ confidence tag
```
Quantity editing is an **inline stepper/slider on the logged row** — never a separate form screen.

### Log-a-set flow (target: 1 tap per set once in workout)
```
Train ──"Repeat last workout"/routine──▶ Workout screen
  ┌ Bench Press          ┐
  │ last: 135×8, 135×8   │  ← previous session inline, always visible
  │ ① 135 × 8   [✓]      │  ← row pre-filled from last time;
  │ ② 135 × _   [✓]      │     tap ✓ = set logged, rest timer auto-starts
  │ + add set            │     (Live Activity on lock screen)
  └──────────────────────┘
  PR hit → brief spring badge + haptic, never blocks input
```
Weight/reps adjust via compact steppers on the row. Finishing shows a 1-screen summary (volume, PRs, duration).

### Progress screen
Segmented: **Strength** (per-exercise e1RM/top-set line chart, exercise picker sorted by most-trained) · **Body** (weight raw dots + EMA trend line, 7/30/90/all toggle; measurements) · **Nutrition** (calorie/macro adherence bars by week). All Swift Charts, minimal ink, no dashboard clutter.

**Every screen ships with explicit empty, loading (skeleton shimmer for remote food search only), error (inline retry, never modal), and offline states (badge + everything still works).**

---

## 4. Visual Design System

- **Palette:** near-black/near-white neutrals (true dark `#0C0C0E` base in dark mode) + **one accent: a confident lime-green** (`#C8F04A`-family, Whoop/Oura energy) used only for primary actions, completed rings, PRs. Semantic colors via asset catalog, both modes first-class.
- **Type:** SF Pro (Rounded for numerals/rings), tight scale defined once in `Theme.swift` (Display 34/28, Title 22, Body 17, Caption 13), 8pt spacing grid, 12–16pt corner radii, **no shadows** — separation via surface tones.
- **Motion:** spring(response 0.3, damping 0.8) standard; ring fills, set-check bounce, PR badge; all 150–350ms, interruptible, gated on `accessibilityReduceMotion`.
- Haptics: `.light` on log, `.success` notification on PR/goal close.

---

## 5. Security Architecture (built-in per phase, audited in Phase 4)

- **Auth:** Sign in with Apple primary (server verifies identity token via Apple JWKS with `jose`); email/password fallback with **Argon2id**, rate-limited (`@fastify/rate-limit`: 5/min on auth routes).
- **Sessions:** 15-min JWT access tokens + opaque refresh tokens (256-bit random, **SHA-256 hash stored**, rotation with family-reuse detection → revoke family). Tokens in **Keychain** (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), never UserDefaults.
- **Transport:** ATS fully on, no exceptions; TLS 1.2+; cert pinning noted as a production toggle.
- **API:** every route authenticated via JWT middleware; user ID **only** from token claims; Zod-validated bodies; Drizzle parameterized queries; audit-friendly error responses (no stack leaks).
- **On device:** optional Face ID app-lock (`LAContext`), sensitive screens excluded from app-switcher snapshot, no health data in logs; SwiftData store under iOS file protection `.completeUntilFirstUserAuthentication`; progress photos `.complete`.
- **Privacy:** HealthKit data never leaves device (steps/sleep synced values are manual-entry only unless user opts in — documented in a PRIVACY.md); account + data deletion endpoint (`DELETE /v1/me`) from day one.
- **Phase 4 gate:** written OWASP Mobile Top 10 + API Top 10 checklist pass against actual code.

---

## 6. Repo Layout

```
FitTrack/
├── ios/
│   ├── project.yml              (XcodeGen — run `xcodegen generate` on Mac)
│   ├── FitTrack/
│   │   ├── App/                 (entry, DI container, app lock)
│   │   ├── DesignSystem/        (Theme, components: Ring, StatBar, Stepper…)
│   │   ├── Models/              (SwiftData @Model types)
│   │   ├── Features/{Today,Train,Nutrition,Progress,Profile}/
│   │   ├── Services/            (FoodSearch, HealthKit, Sync, PRDetector…)
│   │   └── Resources/           (exercises.json seed, asset catalog)
│   ├── FitTrackWidgets/         (rings widget + rest-timer Live Activity)
│   └── FitTrackTests/           (Swift Testing)
├── backend/
│   ├── src/{routes,auth,sync,nutrition,db}/
│   ├── drizzle/                 (schema + migrations)
│   └── test/                    (vitest — runnable on this machine)
├── docs/ARCHITECTURE.md, PRIVACY.md, SECURITY-REVIEW.md
└── README.md                    (Mac build steps, backend run steps)
```

---

## 7. Phased Build Order

**Phase 1 — Local-only core (usable app, no account needed):**
`git init`, repo scaffold, design system + Theme, SwiftData models + exercise seed JSON, **Today screen**, workout logging (routines, repeat-last, previous-performance inline, rest timer via local notification, PR detection + celebration), meal logging (recents/frequents, USDA+OFF search w/ local cache, saved meals, inline portion stepper), water + weight + measurements, Progress charts (EMA weight trend, per-exercise strength), all empty/offline states. Unit tests: macro math, EMA, PR detection, e1RM.

**Phase 2 — Backend + accounts + sync:**
Fastify API (auth as §5, all CRUD/sync endpoints), Drizzle schema + migrations, sync engine (dirty-flag push queue, cursor pull, LWW + tombstones), Keychain session storage, sign-in UI, conflict tests + auth tests in vitest (**run/verified here on Windows**), deploy notes for Fly/Neon.

**Phase 3 — Integrations:**
HealthKit read (steps, sleep) with clear permission rationale screens, barcode scanner (VisionKit → OFF lookup), freeform AI estimate endpoint + client UI, WidgetKit rings widget, rest-timer **Live Activity**.

**Phase 4 — Polish + hardening:**
Animation/haptics pass, full accessibility audit (Dynamic Type, VoiceOver labels, reduced-motion paths, tap targets), Face ID app lock, snapshot privacy, performance pass on long lists, empty-state copy polish, **written OWASP self-review**, dependency scan setup (Dependabot config), final README.

Each phase ends with: backend tests run here; iOS build checklist for the Mac (`xcodegen generate && open FitTrack.xcodeproj`, build to simulator, manual smoke script per feature).

---

## 8. Verification

- **Backend:** `npm test` (vitest) + `npm run dev` against local Postgres (Docker) — executed on this Windows machine each phase.
- **iOS:** cannot compile on Windows. Mitigations: zero third-party deps, conservative API usage, per-phase Mac build checklist in README with expected results; user builds on Mac and reports errors back for fix-up. First Mac build is scheduled at the **end of Phase 1**, not the end of the project.
- **End-to-end:** manual smoke scripts per phase (log meal in 2 taps, log set in 1 tap, kill network and log everything, then reconnect and verify sync in Phase 2+).
