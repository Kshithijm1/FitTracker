# Deploying the FitTrack backend

Phase 2 target: **Fly.io** (API) + **Neon** (managed Postgres). See PLAN.md §1 for the
Fly/Railway tradeoff — Fly is used below; Railway steps are equivalent (push image, set the
same env vars, point `DATABASE_URL` at Neon).

## 1. Provision Neon (Postgres)

1. Create a project at [neon.tech](https://neon.tech).
2. Copy the pooled connection string (Neon's dashboard → **Connection Details** → enable
   "Pooled connection"). This becomes `DATABASE_URL`.
3. Create a **branch** named `staging` for pre-production testing — Neon branches are
   copy-on-write, so staging can mirror prod data without doubling storage cost.
4. Run migrations against the branch you're deploying to:
   ```
   cd backend
   DATABASE_URL=<neon-connection-string> npm run db:migrate
   ```

## 2. Provision Fly.io (API)

1. Install `flyctl` and `fly auth login`.
2. From `backend/`, run `fly launch` — decline the offer to create a Postgres app (Neon is
   the database). This generates a `fly.toml`; set the internal port to match `PORT` (3000).
3. Set secrets (never commit these — they live only in Fly's secret manager, PLAN.md §5):
   ```
   fly secrets set \
     DATABASE_URL="<neon-pooled-connection-string>" \
     JWT_ACCESS_SECRET="$(openssl rand -hex 32)" \
     APPLE_BUNDLE_ID="com.fittrack.app" \
     APPLE_TEAM_ID="<your-apple-team-id>" \
     ANTHROPIC_API_KEY="<phase-3-only>"
   ```
4. Deploy:
   ```
   fly deploy
   ```
5. Confirm health: `curl https://<your-app>.fly.dev/health` → `{"status":"ok"}`.

## 3. Point the iOS client at it

Update `ios/FitTrack/Services/Networking/BackendConfig.swift`'s `RELEASE` branch URL to the
Fly app's `https://<your-app>.fly.dev`, then rebuild the Release configuration.

## 4. Staging vs production

Run two Fly apps (`fittrack-api-staging`, `fittrack-api`) against two Neon branches
(`staging`, `main`). Promote by merging the staging branch's schema changes via the same
migration files — never hand-edit the staging/prod schema out of band.

## 5. Rotation & incident response

- Rotate `JWT_ACCESS_SECRET` by setting a new Fly secret and redeploying; this invalidates
  all outstanding access tokens (15-min TTL, so the blast radius is small) but not refresh
  tokens — pair a secret rotation with `revokeAllSessionsForUser` for any account under
  suspicion.
- Neon's point-in-time restore covers accidental data loss; Fly's rolling deploys cover
  process crashes. Neither substitutes for `docs/SECURITY-REVIEW.md`'s Phase 4 checklist.
