# Teman Kereta Admin

Admin panel web ringan for TK (PRD §36), built with Next.js (App Router) and
Supabase. Reads/writes go through the service-role key exclusively — see
`lib/supabase/service.ts` — never the anon/authenticated client, matching
the same "reference data writes go through a trusted server connection, not
a client" posture as `docs/backend-local.md` in the repo root.

## Running locally

1. Bring up a Supabase stack — either the local one (`npx supabase start`
   from the repo root) or a hosted project with the schema migrations from
   `supabase/migrations/` applied.
2. Copy `.env.local.example` to `.env.local` and fill in
   `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` /
   `SUPABASE_SERVICE_ROLE_KEY` from `npx supabase status` (local) or your
   project's API settings (hosted).
3. Create an admin account (there is no self-service signup — this is an
   internal tool):
   ```bash
   npm install
   node scripts/bootstrap-admin.mjs <email> <password> ["Display name"]
   ```
4. `npm run dev`, then sign in at `/login`.

## Authorization model

Signing in with Supabase Auth is **not** enough to use the panel — the
signed-in user's id must also exist in `public.admin_users` (checked in
`lib/dal.ts`'s `verifyAdminSession()`, server-side, via the service-role
client — never a client-visible RLS policy). `proxy.ts` only does an
*optimistic* redirect-if-signed-out check (per Next.js's own auth guide);
the real authorization check runs in `verifyAdminSession()`, called at the
top of every protected page **and** every mutating server action.

Every mutation calls `recordAudit()` (`lib/audit.ts`) right after it
succeeds, writing to `public.audit_log` — this is what backs the "Audit
Log" page.

## What's real vs. deferred

Built and verified end-to-end this round (login → mutate → audit log, all
tested against a real running Supabase stack, not just compiled):

- **Login** — Supabase Auth email/password, gated by `admin_users`.
- **Dashboard** — live counts (operators/lines/stations/active alerts/
  pending reports) and "data last updated" timestamps, queried directly
  from the reference tables — no mock numbers.
- **Kelola operator** — create, edit (`/operators/[id]/edit`), toggle
  active, delete.
- **Kelola jalur** — create, edit (`/lines/[id]/edit`, including
  reassigning the operator), delete.
- **Kelola stasiun** — create, edit (`/stations/[id]/edit`, full fields
  including coordinates and `facilities` as raw JSON), delete.
- **Kelola service alerts** — publish, mark resolved (sets `ends_at`).
- **Moderasi laporan pengguna** — list + change `status`.
- **Audit log** — read-only view of every write made through this panel.
- **Mode maintenance / Remote configuration** — a real, database-backed
  toggle and JSON editor against `public.app_config`. **The Flutter app
  does not read this table yet** — toggling maintenance mode here has no
  effect on the mobile app until that read path is built there. Don't
  claim this is wired end-to-end; it's the admin-side half only.

- **Impor GTFS** (`/gtfs-import`) — uploads a GTFS Schedule (static) `.zip`
  and imports it into the real reference schema: upserts stations (by
  `code`) and lines (by `code` under the selected operator), then expands
  `calendar.txt`/`calendar_dates.txt` into concrete dated `trips`/
  `stop_times` rows for an admin-chosen window (1–30 days — `trips.
  service_date` is a concrete date column in this schema, not a recurring
  pattern, so a real feed's recurring calendar has to be materialized
  per-date). Verified against the real bundled KRL Jabodetabek feed
  (84 stations, 5 lines, 984 trip patterns → 2,952 dated trips, 48,585
  stop_times for a 3-day window) — and verified **idempotent**: re-running
  the identical import produced the exact same row counts, not duplicates.
  Uses `public.import_gtfs_trips()` (new migration) for the trips upsert,
  since `trips`' natural-key unique index is partial (`where
  external_trip_id is not null`) and PostgREST's upsert can't express that
  predicate in its `ON CONFLICT` target — confirmed by testing a plain
  `.upsert()` against it directly, which failed with "no unique or
  exclusion constraint matching the ON CONFLICT specification."

- **Kelola destinasi** (`/nearby-places`) — create, edit, delete places
  around a station (mall, kuliner, dsb.), scoped to a selected station.

**Not built at all yet** (see the repo root `ENGINEERING.md`'s "Known
gaps" for the full picture):

- **Validasi feed** — the importer above parses and validates a feed as
  a side effect of importing it, but there's no separate "check this feed
  without committing it" dry-run mode yet.
- **Kelola notifikasi** — there's no server-push infrastructure at all
  (the mobile app only has local, on-device notifications) — building a
  "send notification" form here would be a UI with nothing real behind it,
  so it was deliberately left out rather than half-built.

## Scripts

- `node scripts/bootstrap-admin.mjs <email> <password> [display_name]` —
  create (or reuse) a Supabase Auth user and add it to `admin_users`.
- `npm run refresh-vehicle-positions` (or
  `node scripts/refresh-vehicle-positions.mjs [poll_seconds]`) — polls
  `public.refresh_estimated_vehicle_positions()` (new migration
  `20260805170000_estimated_vehicle_positions.sql`) every 20s by default,
  keeping `public.vehicle_positions` filled with schedule-based estimated
  positions for trips currently in service. Only has a visible effect on the
  Flutter app when it runs with `TRANSIT_PROVIDER=local_supabase` — see
  ENGINEERING.md's "Estimated vehicle positions" section for the full
  design/verification notes. Not a managed/supervised process — just run it
  alongside `npm run dev` during development.
