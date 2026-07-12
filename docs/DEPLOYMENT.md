# Deploying the FitTrack backend

Personal/free-tier target: **Render** (API, free web service) + **Neon** (managed Postgres,
free tier). Both require no payment method for this scale. A `render.yaml` Blueprint lives
at `backend/render.yaml` so Render can provision the service from the repo directly.

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

## 2. Provision Render (API)

1. Push this repo to GitHub (already done: `Kshithijm1/FitTracker`).
2. In the [Render dashboard](https://dashboard.render.com), click **New +** → **Blueprint**,
   and connect the `FitTracker` repo. Render will detect `backend/render.yaml` and propose
   the `fittrack-api` web service on the **free** plan.
3. On the "Environment" step, fill in the secrets marked `sync: false` in `render.yaml`
   (never commit these):
   - `DATABASE_URL` — the Neon pooled connection string from step 1
   - `JWT_ACCESS_SECRET` — output of `openssl rand -hex 32`
   - `APPLE_TEAM_ID` — leave blank unless/until Sign In with Apple is re-enabled
   - `ANTHROPIC_API_KEY` — leave blank until Phase 3's AI estimate feature is needed
4. Deploy. Render builds with `npm install && npm run build` and runs `npm start`
   (see `backend/render.yaml`).
5. Confirm health: `curl https://<your-service>.onrender.com/health` → `{"status":"ok"}`.

**Free tier tradeoff:** the service spins down after ~15 minutes of inactivity and takes
~30-60 seconds to wake up on the next request — expect a slow first request after the app
has been idle a while.

## 3. Point the iOS client at it

Update `ios/FitTrack/Services/Networking/BackendConfig.swift` with the Render URL from step
2 (`https://<your-service>.onrender.com`), for both the `DEBUG` and `RELEASE` branches if you
want on-device builds to hit the hosted server instead of your Mac's local IP.

## 4. Staging vs production

Run two Render services (`fittrack-api-staging`, `fittrack-api`) against two Neon branches
(`staging`, `main`). Promote by merging the staging branch's schema changes via the same
migration files — never hand-edit the staging/prod schema out of band.

## 5. Rotation & incident response

- Rotate `JWT_ACCESS_SECRET` by updating the Render env var and redeploying; this
  invalidates all outstanding access tokens (15-min TTL, so the blast radius is small) but
  not refresh tokens — pair a secret rotation with `revokeAllSessionsForUser` for any
  account under suspicion.
- Neon's point-in-time restore covers accidental data loss; Render's redeploys cover process
  crashes. Neither substitutes for `docs/SECURITY-REVIEW.md`'s Phase 4 checklist.
