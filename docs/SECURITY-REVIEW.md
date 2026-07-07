# Security Self-Review — Phase 4 Gate

Written self-review against the **OWASP Mobile Top 10 (2024)** and **OWASP API Security Top 10
(2023)**, checked against the actual code in this repo (not a generic checklist). Each item is
marked **Pass**, **Partial** (works, with a known gap), **Gap — fixed** (found during this review
and remediated in the same pass), or **N/A** (no attack surface / feature not built). Dates:
reviewed 2026-07-04, against the Phase 1–4 codebase.

---

## OWASP Mobile Top 10 (2024)

### M1 — Improper Credential Usage
**Pass.** Access/refresh tokens live in Keychain (`KeychainService.swift`) under
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — never `UserDefaults`, never iCloud-synced.
No secrets are embedded in the iOS bundle: `ANTHROPIC_API_KEY` stays server-side
(`backend/src/nutrition/estimateClient.ts`); the USDA `DEMO_KEY` fallback is a public,
non-secret rate-limited key by design (documented in `USDAProvider.swift`), not a credential leak.

### M2 — Inadequate Supply Chain Security
**Partial.** iOS ships **zero third-party SwiftPM dependencies** (a deliberate PLAN.md §1
decision) — no supply-chain surface at all on the client. Backend dependencies are scanned via
`npm audit` (0 vulnerabilities in production deps as of this review — a real `drizzle-orm` SQL
injection advisory was caught and fixed during Phase 2 by upgrading past the vulnerable range)
and now monitored continuously via `.github/dependabot.yml`.
**Known gap:** `npm audit` isn't wired into CI yet (no CI pipeline exists at all for this
solo project) — it's run manually. Acceptable for current scale; revisit if a CI pipeline is added.

### M3 — Insecure Authentication/Authorization
**Partial.** Sign in with Apple verified against Apple's JWKS with audience-checked against
`APPLE_BUNDLE_ID` (`backend/src/auth/apple.ts`). Email/password uses Argon2id (`password.ts`).
15-minute JWT access tokens; refresh tokens are 256-bit random, SHA-256-hashed at rest, rotated
on every use with **family-wide revocation on reuse detection** (`sessionService.ts`) — covered
by dedicated tests (`test/auth.test.ts`). Auth routes are rate-limited at 5/min.
**Known gap:** rate limiting is per-IP (`@fastify/rate-limit` default keying), not per-account —
a distributed attacker spreading requests across many IPs could still brute-force one account's
password beyond the per-IP ceiling. Acceptable at current scale (Argon2id's cost factor is the
real defense against a successful guess; account lockout is a Phase 5+ candidate if this ever
sees real abuse).

### M4 — Insufficient Input/Output Validation
**Gap — fixed.** Every backend route validates its body/query with Zod
(`sync/schemas.ts`, `routes/auth.ts`, `routes/nutrition.ts`) — no raw `request.body` access
anywhere. **Found during this review:** `OpenFoodFactsProvider.lookup(barcode:)` interpolated an
unvalidated VisionKit-scanned string directly into a force-unwrapped `URL(string:)` — a
barcode payload containing URL-breaking characters (VisionKit's `.barcode()` isn't guaranteed
digits-only depending on symbology) would have crashed the app. **Fixed**: the barcode is now
validated as digits-only before being used, and the `URL(string:)` force-unwrap was removed in
favor of a graceful `nil` return.

### M5 — Insecure Communication
**Pass.** ATS is fully on with **no exceptions** in `Info.plist` (verified: no
`NSAppTransportSecurity` key exists in `project.yml`). The `http://localhost:3000` dev endpoint in
`BackendConfig.swift` relies on ATS's built-in loopback exception, not a manual exception — this
only applies to Simulator-to-Mac traffic, never a real device talking to a real server. Certificate
pinning is deliberately deferred (documented in PLAN.md §5 as "a production toggle") — acceptable
for a pre-launch app with no production deployment yet.

### M6 — Inadequate Privacy Controls
**Partial.** HealthKit data (`HealthKitService.swift`) is read-only, never written back to Health,
and — critically — **never included in the sync engine's `SYNCABLE_TABLES`**, so steps/sleep
sourced from HealthKit never leave the device (only manually-entered values sync). App-switcher
snapshot redaction was added this review (`PrivacyCoverView.swift`, wired in `FitTrackApp.swift`)
so health/nutrition data is never visible in the multitasking UI. `DELETE /v1/me` provides
account+data deletion from day one (auth.ts).
**Known gap / N/A:** `ProgressPhoto` exists as a data model (per the original data-model doc) but
**no capture/gallery UI was ever built** in Phases 1–4 — there is no photo feature to audit for
its stated `.complete` file-protection requirement. Flagging this explicitly rather than claiming
compliance for a feature that doesn't exist: if progress photos are built later, the `.complete`
file protection level must be applied to the saved image files at that time.

### M7 — Insufficient Binary Protections
**N/A (accepted risk).** No jailbreak detection, anti-tampering, or string/symbol obfuscation.
Standard for a solo-developer app at this stage; the cost (added complexity, false-positive risk
on legitimate jailbroken-but-not-malicious users) isn't justified by the threat model of a
personal fitness tracker. `ENABLE_HARDENED_RUNTIME: YES` is set (`project.yml`) as the one
low-cost mitigation that's actually in place.

### M8 — Security Misconfiguration
**Partial.** Backend fails fast at boot on missing/malformed env config (`env.ts` — Zod-validated,
no partially-configured server ever starts). Error responses never leak stack traces
(`app.ts`'s `setErrorHandler` collapses every 5xx to a generic message).
**Known gap:** no `@fastify/helmet` — response security headers (`X-Content-Type-Options`,
`Strict-Transport-Security`, etc.) aren't set. Lower-impact for a pure JSON API with no HTML
surface, but cheap to add; noted as a pre-launch follow-up rather than blocking.

### M9 — Insecure Data Storage
**Gap — fixed.** Keychain tokens already had the right protection class (see M1). **Found during
this review:** the SwiftData store itself had no file-protection attribute set — PLAN.md §5
calls for `.completeUntilFirstUserAuthentication` on the store, but `AppContainer` never applied
it (a real gap between the stated design and the shipped code, not a documentation error).
**Fixed** in `AppContainer.applyFileProtection(to:)`, applied to the store file and its `-wal`/
`-shm` siblings at container creation.

### M10 — Insufficient Cryptography
**Pass.** Refresh tokens: `crypto.randomBytes(32)` (256 bits) hashed with SHA-256 before storage
(`tokens.ts`). Passwords: Argon2id (OWASP-recommended variant, resists both GPU and side-channel
attacks). JWT: HS256 with a required 32+-byte secret (`env.ts` enforces `min(32)`). No custom
crypto anywhere — all primitives come from `jose`, `argon2`, and Node's `node:crypto`.

---

## OWASP API Security Top 10 (2023)

### API1 — Broken Object Level Authorization
**Pass, tested.** `applyIncomingRecord` (`sync/engine.ts`) checks `existing.userId !== userId`
before allowing any overwrite of a record that already exists under a different owner, returning
`rejected_not_owner` rather than applying the write. `GET /v1/sync/pull` scopes every table query
by the authenticated `userId`. Covered by a dedicated test: *"rejects a push that targets a record
id owned by a different user"* (`test/sync.test.ts`).

### API2 — Broken Authentication
**Pass.** See Mobile M3 above — same mechanism, same tests.

### API3 — Broken Object Property Level Authorization
**Pass.** Every sync push schema (`sync/schemas.ts`) is an explicit Zod allowlist of exactly the
fields a client may set per table — no mass-assignment surface. `userId` is never read from the
request body on any route; it always comes from the verified JWT's `sub` claim
(`auth/middleware.ts`).

### API4 — Unrestricted Resource Consumption
**Gap — fixed.** `POST /v1/sync/push` and `GET /v1/sync/pull` had **no rate limiting at all**
before this review, and the push schema's per-table arrays had **no size cap** — a buggy or
malicious client could submit an effectively-unbounded array of fake records in a single request.
**Fixed:** both routes now carry a 60/min rate limit (`routes/sync.ts`), and every per-table array
in the push schema is capped at 500 records (`sync/schemas.ts`) — a client with a larger backlog
simply makes more requests. `POST /v1/nutrition/estimate` was already rate-limited at 20/min
specifically to bound cost exposure on the paid Anthropic upstream call.

### API5 — Broken Function Level Authorization
**Pass.** `DELETE /v1/me` requires auth and only ever acts on `request.userId` (never a body-
supplied ID) — a user can only delete their own account. No admin/privileged endpoints exist.

### API6 — Unrestricted Access to Sensitive Business Flows
**Pass.** The one metered/costed flow — `POST /v1/nutrition/estimate` (calls paid Claude Haiku
API) — is both auth-gated and rate-limited (20/min) specifically to bound abuse cost, by design
(see `docs/DEPLOYMENT.md` pricing note).

### API7 — Server-Side Request Forgery (SSRF)
**N/A.** The backend accepts no user-supplied URLs anywhere — no webhook registration, no
"fetch this URL" endpoint. No SSRF attack surface exists.

### API8 — Security Misconfiguration
**Partial.** See Mobile M8. Additionally: no CORS plugin is registered, which is correct for the
current client (native iOS only, no browser JS ever calls this API) — but would need explicit,
narrow CORS configuration before any web client is added. Documented here so it isn't
accidentally opened wide (`*`) if that day comes.

### API9 — Improper Inventory Management
**Pass.** Single Fastify app, all routes under an explicit `/v1/` prefix signaling forward
intent to version, no deprecated/shadow endpoints (this is the API's first version).

### API10 — Unsafe Consumption of Third-Party APIs
**Partial.** Anthropic API errors are caught and collapsed to a generic 503
(`EstimateUnavailableError`) — the client never sees upstream error detail. OFF/USDA responses
are decoded into typed Swift structs (`OpenFoodFactsProvider.swift`, `USDAProvider.swift`), not
trusted blindly.
**Known gap:** iOS-side calls to OFF/USDA/Anthropic rely on `URLSession`'s default timeout
(~60s) rather than an explicit shorter timeout — a slow third party could make the log-a-meal
flow feel hung longer than necessary. Low severity (it's a UX/resilience issue, not a security
one), noted for a future pass.

---

## Summary of fixes made during this review

Three concrete issues were found and fixed while writing this document (not just documented as
future work):

1. **Crash/injection risk**: unvalidated barcode string force-unwrapped into a URL
   (`OpenFoodFactsProvider.swift`).
2. **Missing file protection**: SwiftData store had no `.completeUntilFirstUserAuthentication`
   attribute despite PLAN.md §5 requiring it (`AppContainer.swift`).
3. **Unbounded sync endpoints**: no rate limit and no array-size cap on `/v1/sync/push`/`pull`
   (`routes/sync.ts`, `sync/schemas.ts`).

Everything else marked **Partial** above is a known, intentionally-accepted gap appropriate for
a pre-launch, solo-developer project — not an oversight. Re-run this review before any public
launch, and specifically before adding a web client (CORS) or a CI pipeline (wire `npm audit` in).
