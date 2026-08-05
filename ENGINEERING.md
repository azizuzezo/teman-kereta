# ENGINEERING.md — Teman Kereta implementation notes

This file tracks **what is actually wired up and working today**, as opposed to
what `PRD.md` asks for. Read `PRD.md` for requirements; read this file for
ground truth on the current codebase. Update it whenever a flow goes from
"exists" to "actually connected end-to-end," or when something here turns out
to be stale.

Last verified: 2026-08-05. `flutter analyze` clean (no errors). `flutter
test` — 60/60 passing + 1 skipped (the live-Supabase integration test)
across `test/core`, `test/data`, `test/domain`, `test/features`,
`test/integration`, and widget tests for the app shell, GTFS import page,
and ride-detection confirm page. Beyond unit/widget tests, this project has
now had several rounds of genuine on-device verification (not just
compiled/analyzed) against a live Android emulator, installed via `adb` and
driven via `adb shell input`/`uiautomator`, confirmed via `adb shell
screencap`: `local_supabase` against a real running Supabase stack, the
GTFS import UI + a real Profile-page bug fix, the bundled real KRL feed's
auto-import, and a real "Data Demo" banner bug fix — see the sections below
for each.

## Architecture at a glance

- **State management**: Riverpod 3 (`flutter_riverpod`), no code generation —
  providers are hand-written `Provider`/`FutureProvider`/`StreamProvider`/
  `NotifierProvider`/`AsyncNotifierProvider` top-level `final`s.
- **Navigation**: `go_router`, defined in `lib/app/router/app_router.dart`. A
  `StatefulShellRoute.indexedStack` holds the 5 bottom-nav tabs (Beranda,
  Jadwal, Peta, Jelajahi, Profil); everything else pushes onto the root
  navigator (`parentNavigatorKey: _rootNavigatorKey`).
- **Local persistence, two separate mechanisms** (this is intentional but
  easy to forget):
  - `SharedPreferences` via `lib/core/preferences/preferences_store.dart`
    (`PreferencesStore` / `StoredPreferences`) — small scalar settings:
    onboarding flag, theme, reduce-motion, offline-mode toggle, favorite
    route string, active-trip JSON snapshot, home/work station ids, ride
    detection enabled + suppression date, vibration/sound/threshold,
    text scale.
  - Drift (SQLite) via `lib/core/database/app_database.dart` /
    `database_provider.dart` (`appDatabaseProvider`) — used for things that
    are naturally row-based: `CachedStations` (offline station fallback),
    `CompletedTrips` (trip history), `NotificationLogEntries` (notification
    center), `UserReports` (local report submissions).
  - **`FavoriteRoutes` and `ActiveTripSnapshots` Drift tables exist but are
    dead** — those two concerns are actually implemented via
    `SharedPreferences` (`favorite_route_controller.dart`,
    `PreferencesStore.activeTripSnapshot`). Don't be surprised these Drift
    tables are always empty; either wire them up for real or drop them.
- **Data providers**: `lib/data/providers/provider_registry.dart` switches on
  `AppEnvironment.provider` (`TRANSIT_PROVIDER` env var) between `mock`,
  `gtfs`, `official_api`, `local_supabase`. Full fallback matrix and how to
  configure GTFS-RT feed URLs is documented in `docs/backend-local.md` — read
  that before assuming any given provider kind actually does what its name
  implies.

## Active Trip (state machine)

`lib/domain/entities/active_trip.dart` defines all 13 PRD §30 states.
**Only 8 are ever assigned** by `ActiveTripController`
(`lib/features/active_trip/presentation/active_trip_controller.dart`):
`onBoard`, `approachingTransfer`, `transferring`, `approachingDestination`,
`arrived`, `missedDestination`, `completed`, `cancelled`. Transfer detection
comes from `TransitTrip.transferBoundaries` (derived from consecutive rail
legs in `lib/domain/entities/transit_models.dart`) — a trip only gets a
transfer boundary if `MockTransitProvider` (or a real provider) actually
produces two separate rail `TripLeg`s joined at the same station, not just a
single leg with a `transferInstruction` string.

**All 13 states are now reachable** (as of round 5), but by two different
controllers, not one: the 8 on-board states above stay owned by
`ActiveTripController`/`ActiveTripSession`. The 5 pre-boarding states
(`idle`, `nearStation`, `atStation`, `possibleBoarding`, `confirmingTrip`)
are owned by `RideDetectionController`'s `RideDetectionPhase` (see "Ride
detection" below) — a *separate* piece of state, not a field on
`ActiveTripSession`. `RideDetectionController.confirmStart()` is the bridge:
once the user taps "Ya, mulai", it calls `ActiveTripController.start()`,
which is where the `RideDetectionPhase` handoff to `ActiveTripState.onBoard`
actually happens. If you need "one true current state" for some future UI,
you have to read both providers — there's no single unified stream yet.

Trip completion (`ActiveTripController.complete()`) also logs a summary row
to `CompletedTrips` via `_logHistory()` — wrapped in `try/on Object` so a DB
failure never blocks finishing a trip. Round-trip correctness of the Drift
layer itself is covered by `test/core/app_database_test.dart` (in-memory
`NativeDatabase.memory()`), but `_logHistory()`'s call site inside
`ActiveTripController` still isn't — `active_trip_controller_test.dart` never
calls `complete()`.

## Ride detection (PRD §9, Tahap 4)

Entirely event-driven, no continuous GPS polling (PRD §7/§31):

- **Native** (`android/app/.../ActivityRecognitionManager.kt` +
  `ActivityTransitionReceiver.kt`): Activity Recognition **Transition API**
  (not the older polling `requestActivityUpdates`) for `IN_VEHICLE`/
  `ON_FOOT`/`STILL`. `StationGeofenceManager.kt`/`StationGeofenceReceiver.kt`
  handle station **ENTER, EXIT, and (as of round 5) DWELL** transitions — a
  90s `setLoiteringDelay` so "briefly passing near a station" (ENTER) is
  distinguishable from "actually stopped there" (DWELL → `atStation`). Both
  write to `NativeStateStore` (SharedPreferences on the native side), which
  `NativeTripService` (Dart) polls via `getLastGeofenceEvent()` /
  `getLastActivityEvent()` — a cheap SharedPreferences read through the
  platform channel, not a live stream.
- **Dart**: `RideDetectionController`
  (`lib/features/ride_detection/presentation/ride_detection_controller.dart`)
  is polled every 25s by `RideDetectionWatcher`
  (wraps the whole app shell in `app_router.dart`) while
  `AppSettings.rideDetectionEnabled` is true and no trip is already active.
  Its state is a `RideDetectionPhase` (state machine below), not a bare
  assessment. On a geofence ENTER/DWELL it moves to `nearStation`/
  `atStation` (silent, no prompt — only ever a subtle Home-page banner via
  `_RideDetectionPhaseBanner`). On EXIT it runs `RideDetectionEngine`
  (`lib/domain/usecases/ride_detection_engine.dart`, pure & unit-tested) over:
  activity type, a nearby scheduled departure, a matching saved
  home/work/favorite route, and a subsequent-station geofence confirmation.
  Score <50 → `possibleBoarding` (still silent — PRD §9 is explicit that
  below-threshold must never prompt); 50-79/≥80 → `confirmingTrip` with the
  assessment attached, which is what `RideDetectionWatcher` actually watches
  for to fire the notification + push `/ride-detection`.
- **UI**: `RideDetectionConfirmPage` (route `/ride-detection`) reads
  `phase.assessment` — "Ya, mulai" / "Pilih kereta lain" / "Bukan" /
  "Jangan tanya lagi hari ini". Enabling the feature (Profile → "Deteksi
  otomatis naik KRL") requests the `ACTIVITY_RECOGNITION` permission (via
  `MainActivity.onRequestPermissionsResult`) and registers geofences for
  home/work/favorite stations — never on its own, always from that explicit
  toggle.

## Android home-screen widgets (4/4 exist, but check the data-flow caveat)

`TemanKeretaWidgetProviders.kt` has all four PRD §16 widgets: next-departure
(2×2), daily-route (4×2), active-trip, service-status. **Widgets never fetch
anything themselves** — `lib/core/platform/widget_sync.dart` is the single
place that pushes already-loaded Dart-side data into them
(`syncNextDepartureAndDailyRouteWidgets`, `syncServiceStatusWidget`,
`syncAllHomeScreenWidgets`). It's called from two places: `HomePage`'s
`ref.listen` (reactive, whenever departures/alerts change) and
`WidgetSettingsPage`'s manual "Muat ulang semua widget" button. If you add a
fifth thing a widget should show, wire it through this file, not ad hoc in a
page.

## Geolocation-based "nearest station"

`lib/domain/usecases/nearest_station_finder.dart` (pure haversine + walking
estimate, unit-tested) + `lib/features/stations/presentation/
nearest_station_controller.dart`. One-shot `Geolocator.getCurrentPosition`,
**never calls `requestPermission()` itself** (PRD §10 — permission dialogs
must be explained first; that explanation lives in onboarding/Settings).
Falls back silently to the saved home station + "Lokasi demo" label when
permission isn't already granted. Feeds `HomePage`'s nearest-station card and
the dedicated `NearbyStationsPage` (`/nearby-stations`, PRD §12/page 19,
**list mode only** — there is still no real geographic map in this app, so a
map-mode toggle would be a non-functional button).

## Branding

Real logo integrated 2026-08-05 from user-supplied `TK1.png`. Source PNGs
live in `assets/branding/` (`tk_icon.png` 1024², `tk_logo_full.png` 2000²,
both generated from the original via Python/PIL — **ImageMagick is not
installed on this dev machine**; `convert` on `PATH` is Windows' unrelated
disk-conversion tool). `lib/core/widgets/tk_logo.dart` renders `tk_icon.png`.
Android launcher icons (`android/app/src/main/res/mipmap-*/ic_launcher.png`)
were regenerated from the same crop at all 5 densities.

## Multimodal continuation

`MultimodalRoutePage` (`/trip/:tripId/multimodal`, linked from
`TripDetailPage`) shows the full leg timeline (shared `TripLegTimelineTile`
widget, used by both trip detail and multimodal pages — don't duplicate it a
third time) plus "Lanjutkan dengan Gojek/Grab" buttons via
`lib/core/utils/ride_hailing_launcher.dart`. **Caveat**: this opens the
installed app via its bare `gojek://` / `grab://` scheme (falling back to
its Play Store listing if not installed) — it does **not** prefill a
destination or fetch a fare, since TK has no partner API access for either.
The exact scheme strings were not verified against current, live
documentation this session; if either stops working, that's the first place
to check.

## Settings surface (Profile page fans out to dedicated pages)

`ProfilePage` now links to: `/history` (trip history, clearable),
`/offline-mode`, `/settings/location`, `/settings/notifications`,
`/settings/accessibility`, `/settings/widgets`, `/about` (static — see
"Known gaps," there is no real update-check), plus the pre-existing
`/help`, `/privacy`, `/report`. The notification bell on `HomePage` now goes
to `/notifications` (real log, was previously mis-wired to `/help`).

Text scale (PRD §33) is applied app-wide via a custom `_ComposedTextScaler`
in `lib/app/app.dart` that multiplies the OS accessibility scale by the
user's in-app slider value — it does not replace the system setting.

## `local_supabase` provider (real; direct trips + single-transfer trips)

`lib/data/providers/supabase_transit_provider.dart` — as of round 5, this is
a genuine implementation, not a stub. Backed by three SQL functions added in
`supabase/migrations/20260805090000_transit_query_functions.sql`:
`get_station_departures`, `search_direct_trips`, `get_trip_stop_codes` (all
`SECURITY INVOKER`, granted to `anon`/`authenticated` — relies on the
existing read policies from the base migration). These exist specifically
because `stop_times.scheduled_*` is stored as `interval` + `trips.service_date`
(see "Catatan waktu GTFS" in `docs/backend-local.md`) and that
`interval → timestamptz` resolution is much better done once in SQL than
reimplemented in Dart.

**Scope limit, updated this round**: `search_direct_trips` only finds a trip
that serves both stations on the *same* `trip_id`. Round 16 added
`search_one_transfer_trips`
(`supabase/migrations/20260805180000_one_transfer_trips.sql`) alongside it —
finds a trip to some third station reachable directly from the origin,
joined to a trip from that same station on to the destination, respecting a
minimum transfer dwell (`p_transfer_buffer_seconds`, default 180s). This is
still **not a general multi-transfer router** — it only ever considers
exactly one line change, and only at a station reachable by direct trips on
both sides. A station pair needing two or more changes still returns
nothing, same honesty posture as before (see that migration's own header
comment for why one transfer covers the overwhelming majority of real KRL
Jabodetabek journeys, given the network's radial-lines-through-a-few-hubs
shape). `SupabaseTransitProvider.searchTrips()` now calls both functions and
merges/sorts the combined results by departure time; a one-transfer result
becomes a genuine 2-leg `TransitTrip` (`transfers: 1`), and
`TransitTrip.transferBoundaries`/`stationIds` (existing getters from Round 1)
handle the leg-boundary bookkeeping automatically since the two legs'
`stationIds` share the transfer station at the junction.

**Verified 2026-08-05** against the local stack with a genuine two-line
scenario, not just the pre-existing single-line seed: added a second demo
line + trip to `supabase/seed.sql` (`DEMO-MRI` -> `DEMO-KPB`, departing 7
minutes after the first trip's own `DEMO-BOO` -> `DEMO-MRI` -> `DEMO-SUD`
trip arrives at `DEMO-MRI`) specifically so a one-transfer journey
(`DEMO-BOO` -> `DEMO-KPB` via `DEMO-MRI`) exists to test against locally,
not only against the real KRL feed imported ad hoc during development.
Confirmed correct via direct `psql` and PostgREST/anon-key calls, then added
a 6th test to `test/integration/supabase_transit_provider_live_test.dart`
asserting the real 2-leg result (`transfers == 1`, both legs meeting at
"Manggarai", one transfer boundary) — all 6 live tests pass. Also
confirmed, while testing against the real imported KRL feed (not the seed),
that a genuine data-quality quirk already existed before this round: the
local dev DB has the same feed imported twice under two different
operator/line rows (`[DATA DEMO] Operator Transit Lokal` and the user's own
separately-created `KAI Commuter`, both named identically per line) — this
produces literal duplicate-looking trip results from *both*
`search_direct_trips` and the new `search_one_transfer_trips` alike. Not a
bug in either function, not touched (per the Round 12 "check provenance
before assuming ownership" lesson) — just worth knowing if search results
against local dev data look doubled.

**Not done this round**: the Dart/Drift-backed `gtfs` provider
(`GtfsStaticScheduleProvider`) still only does direct-trip search — the
same one-transfer *idea* would need its own from-scratch implementation
against Drift queries (Postgres CTEs don't translate directly), which is a
separate, comparable-sized task, not attempted this round.

`watchVehiclePositions`/
`watchTripUpdates`/`watchServiceAlerts` use real Supabase Realtime
(`.stream(primaryKey: ['id'])`) on the raw tables, resolving
`current_station_id`/`next_station_id` UUIDs to station codes via a small
client-side cache (`_stationCodesById`) since Realtime only replicates
tables, not joined views.

`main.dart` now calls `Supabase.initialize()` when `SUPABASE_ENABLED=true`,
before `runApp()`. `supabaseTransitProvider` throws a clear `StateError` if
`TRANSIT_PROVIDER=local_supabase` is selected without `SUPABASE_ENABLED=true`
— it will not silently fall back to something else.

**Runtime-verified 2026-08-05**: Docker Desktop was started and
`npx supabase start` brought up the full local stack (Postgres, PostgREST,
GoTrue, Realtime, Studio, etc.), applied both migrations, and loaded
`seed.sql`. Confirmed via direct `curl` against the PostgREST RPC endpoints
that `get_station_departures`/`search_direct_trips`/`get_trip_stop_codes`
all return correct rows against the real seeded demo trip — note the seed's
`service_date` is a UTC calendar date but `stations.timezone` is
`Asia/Jakarta` (UTC+7), so a naive `service_date + scheduled_departure`
resolves to a UTC instant *before* that date's own UTC midnight (06:02
Jakarta today = 23:02 UTC **yesterday**) — query `p_from` accordingly, this
tripped up the first manual test attempt and is worth remembering.

Beyond raw SQL, `test/integration/supabase_transit_provider_live_test.dart`
now exercises the actual Dart `SupabaseTransitProvider` class end-to-end
against that live stack — `getStations`, `getStation`, `getStationDepartures`,
`searchTrips`, and `watchVehiclePositions` (real Supabase Realtime, not
mocked) all passed. This test is skipped by default (`flutter test` alone
never touches it — `bool.fromEnvironment('LIVE_SUPABASE')` gates it) since
normal dev/CI runs have no live Supabase instance; run it explicitly with
`npx supabase start` running, then
`flutter test --dart-define=LIVE_SUPABASE=true test/integration/supabase_transit_provider_live_test.dart`.

Along the way, this also surfaced and fixed a real bug in
`NativeTripService.updateServiceStatusWidget`: it was calling `_stationName()`
(a *station*-id lookup) on `ServiceAlert.lineId` (a *line* id) — always a
miss, silently falling back to the raw id. It now just uses `alert.title`
directly, which is what every provider already puts a human-readable string
into.

### Estimated vehicle positions (schedule-based interpolation)

`public.vehicle_positions` existed since the base schema (with exactly the
right `source`/`accuracy_status` columns) but nothing ever wrote to it, so
`local_supabase`'s `watchVehiclePositions()` always streamed an empty list
outside of seed data. Round 15 fixed that with
`public.refresh_estimated_vehicle_positions()`
(`supabase/migrations/20260805170000_estimated_vehicle_positions.sql`): on
each call it deletes all `source = 'estimated'` rows and re-inserts one row
per trip currently inside its scheduled service window (found via
`public.trips`/`public.stop_times`/`public.stations`, the same tables the
admin panel's GTFS importer already populates), straight-line-interpolating
lat/lon between the last-departed and next-arriving station by elapsed
fraction of that leg. Never touches `gtfs_realtime`/`official_api`/`demo`
rows — only ever owns the `estimated` slice.

This is a from-scratch reimplementation of the position-estimation *idea*
found in a third-party "Teman Kereta Live Starter" reference package the
user shared, deliberately **not** wired in as that package designed it: that
package ships its own separate `transit.*` Postgres schema and its own GTFS
importer, which would have meant importing the same feed twice into two
disconnected schemas in the same database. This implementation instead
targets the schema that's already live and already fed by the real admin
panel importer — no second schema, no second importer, no new REST service
for the Flutter app to learn.

The function is `SECURITY DEFINER`, revoked from `public`/`anon`/
`authenticated`, granted only to `service_role` — same posture as every
other admin-side writer in this project. Something has to call it on an
interval; `admin/scripts/refresh-vehicle-positions.mjs` does that (reads
`admin/.env.local` the same way `bootstrap-admin.mjs` does, calls the RPC
every 20s by default, run with `npm run refresh-vehicle-positions` from
`admin/`). There is no `pg_cron` dependency and no separate always-on
service — just a script you run alongside `supabase start`/`npm run dev`
during development. It is not managed by any process supervisor yet; running
it in production would need that.

**Verified 2026-08-05** against the local stack: the SQL function alone
(via `docker exec ... psql`) produced 118 correctly-interpolated rows across
real KRL trips in service at that moment, re-running it immediately
reproduced the same row count (no duplication, confirms the
delete-then-insert approach is idempotent), and a plain PostgREST call with
the local anon key correctly got `42501 permission denied` while the
service-role key succeeded — the grant is doing its job. The poller script's
loop/tick logic was exercised directly (two ticks, 3s apart, both refreshed
successfully). Finally,
`flutter test --dart-define=LIVE_SUPABASE=true test/integration/supabase_transit_provider_live_test.dart`
was re-run with real estimated rows now present in the table and all 5
tests still pass, including `watchVehiclePositions streams the seeded
vehicle over Realtime` — confirming the whole path (SQL function → Postgres
row → Supabase Realtime → `SupabaseTransitProvider._vehiclePositionFromRow`)
works end-to-end, not just the SQL in isolation.

**Not done / explicitly out of scope this round**:
- No GTFS-Realtime passthrough. If a real, licensed GTFS-RT feed URL ever
  exists for KRL Jabodetabek, a second writer could poll it and insert
  `source = 'gtfs_realtime'` / `accuracy_status = 'real_time'` rows the same
  way — the schema already supports both sources coexisting — but there is
  no such feed today, so this only ever produces `estimated` positions. Per
  the reference package's own explicit rule (carried over here): never
  present these as real GPS.
- `public.trip_updates` (delays/predictions) is still never written to by
  anything — that needs real GTFS-RT trip-update data, which doesn't exist,
  so it was left alone rather than fabricated from the schedule.
- This only has a user-visible effect when `TRANSIT_PROVIDER=local_supabase`
  — the app's committed `.env` still runs `TRANSIT_PROVIDER=gtfs`
  (deliberately left as the user's own call, see "Hosted Supabase project"
  below). Nothing changes for the app as currently configured until that
  switch is made.
- The poller is a bare `while` loop with no restart/supervision, and there's
  no equivalent hosted-project verification (only local) — the user applies
  schema migrations to the hosted project themselves.

## Crash monitoring (Sentry)

`sentry_flutter` wraps `runApp()` in `lib/main.dart`, gated by
`AppEnvironment.crashReportingEnabled` (`SENTRY_DSN` non-empty **and**
`!isLocal`) — matches the same "nothing local talks to a remote service"
posture as `validateLocalOnly()`, but as a soft skip rather than a hard
`StateError`, since a stray `SENTRY_DSN` in a local `.env` isn't a
misconfiguration worth crashing over. `tracesSampleRate = 0` and
`sendDefaultPii = false` — full error capture, no performance/session
sampling (keeps a free-tier Sentry quota from being burned) and no PII sent
by default.

**Real incompatibility hit and fixed this round**: `sentry_flutter: ^8.14.2`
(the version `pub get` picked initially) failed native compilation with
`e: Language version 1.6 is no longer supported; use version 2.0 or greater
instead` inside `sentry_flutter:compileDebugKotlin` — its bundled Android
Kotlin sources target a language version older than this project's current
Kotlin/AGP toolchain supports. **Fix: use `sentry_flutter: ^9.26.0` or
later**, not 8.x, on this project's toolchain. (A first retry of the same
build also threw a wall of Maven dependency-resolution errors that looked
network-related — verified via direct `curl` that the failing URLs actually
returned HTTP 200, so that part was a transient Gradle-side hiccup, not the
real issue; the Kotlin language-version error underneath was the real one.)
Bumping to 9.26.0 incidentally pulled `path_provider_android` down to 2.2.23
and `jni` down to 0.14.2 as new transitive constraints — no observed issue
from that, just noted in case something downstream ever looks odd.

Verified this round: `flutter analyze` (whole project, not just
`main.dart`) clean, full 29/29 `flutter test` suite green,
`:app:compileDebugKotlin` succeeds. **Not yet verified**: no DSN has
actually been pointed at a real Sentry project, so no real event has ever
been sent/observed end-to-end — the wiring is compile- and analyze-verified
only. `AndroidManifest.xml` needed no manual Sentry meta-data (the
`sentry_flutter` Gradle plugin's auto-instrumentation handled it).

## GTFS Schedule (static) importer

`lib/data/providers/gtfs_static_importer.dart` (`GtfsStaticImporter`) — real,
not a stub, built round 7 exactly as the "Known gaps" list below used to
demand. Parses a genuine GTFS Schedule feed
(`stops.txt`/`routes.txt`/`trips.txt`/`stop_times.txt`/`calendar.txt`/
`calendar_dates.txt`, all optional-column-tolerant per spec) via the
extended `GtfsScheduleParser` (`lib/data/providers/gtfs_schedule_parser.dart`
— previously only parsed `stops.txt`, dead code otherwise). Accepts either a
raw `.zip` (`importZipBytes`, via the `archive` package) or pre-extracted
file contents (`importFiles`) and writes to six new Drift tables (`GtfsStops`
et al. in `app_database.dart`, schema version bumped 1→2 with a proper
`MigrationStrategy.onUpgrade` this time — worth doing since prior rounds'
new tables skipped that).

`GtfsStaticScheduleProvider` (`lib/data/providers/
gtfs_static_schedule_provider.dart`) reads those tables: real service-day
resolution (weekly `calendar.txt` pattern XOR'd with `calendar_dates.txt`
exceptions), correctly handles GTFS times past midnight (`25:10:00` stays
attached to its origin service day, never wrapped to a 24h clock), a
direct-trip (same `trip_id`, no transfer) search, and — added Round 16 —
single-transfer search (`_oneTransferTrips`), mirroring both
`search_direct_trips` and `search_one_transfer_trips`'s SQL logic from the
`local_supabase` migrations. **This provider is the one currently active**
(`TRANSIT_PROVIDER=gtfs` in the committed `.env`), so this closed the
transfer-search gap for the app as it actually runs today, not just for the
not-yet-selected `local_supabase` path. Two new `AppDatabase` query methods
back it: `transferCandidatesFromOrigin`/`transferCandidatesToDestination`
(self-joins on `gtfs_stop_times` via `alias()`, same pattern as the existing
`directTripCandidates`) — grouped by shared transfer stop id in Dart, cross-
matched excluding same-trip pairs, filtered by a 180s minimum transfer
buffer, resolved against `_ServiceCalendar` per candidate service day. Same
scope limit as the SQL version: exactly one line change, not a general
router. **Falls back to Data Demo automatically** whenever
`gtfsStopCount() == 0` (no feed imported yet), so `TRANSIT_PROVIDER=gtfs`
never shows an empty app — same posture as the offline station cache.
Wired into `stationProvider`/`transitScheduleProvider` in
`provider_registry.dart`; `placesProvider` still correctly falls through to
mock for `gtfs`, since GTFS has no POI data to import.

Verified via 22 unit tests (`test/data/gtfs_schedule_parser_test.dart`,
`gtfs_static_importer_test.dart` — including a real zip round-trip through
the `archive` package —, `gtfs_static_schedule_provider_test.dart` covering
weekday filtering, midnight rollover, the Data Demo fallback, a genuine
one-transfer match, and a negative case where the connecting trip departs
before the transfer buffer elapses) plus a clean full-project `flutter
analyze`.

**Round 16 also closed the "never tested against a real KRL feed" gap**
noted here since Round 7: imported the real bundled
`assets/gtfs/gtfs-krl-jabodetabek-dev.zip` into an in-memory Drift DB inside
a throwaway test and searched Bogor -> Sudirman — found 8 genuine
one-transfer options via Manggarai across two real lines (Bogor Line,
Cikarang Loop Line), confirming the whole path (real feed -> importer ->
calendar resolution -> transfer matching) works end to end, not just
against synthetic fixtures. This surfaced a real, fixed bug along the way:
multiple valid transfer combinations sharing the same departure time
weren't ordered by which arrives soonest (only sorted by departure time,
ties left in insertion order) — fixed by adding `arrivalAt` as a sort
tiebreaker in both `GtfsStaticScheduleProvider.searchTrips()` and
`SupabaseTransitProvider.searchTrips()` (the same issue existed there too,
since the SQL function's own internal duration-based ordering gets
flattened once results are merged with direct trips and re-sorted in Dart).

### In-app import UI (`/settings/gtfs-import`)

Round 7.6 closed the "no in-app UI to trigger an import" gap:
`GtfsImportController` (`lib/features/settings/presentation/
gtfs_import_controller.dart`, an `AsyncNotifier`) + `GtfsImportPage` let a
user pick a `.zip` from device storage and import it directly, with the
current stop count / last-import summary / error state all shown. Linked
from Profile → "Perjalanan & aplikasi" → "Impor jadwal GTFS".

**Real, runtime-verified on an Android emulator** (not just compiled) —
built a synthetic 3-station/1-route/2-trip GTFS feed, pushed it to the
emulator via `adb push` into `/sdcard/Download/`, launched the app, used
`uiautomator dump` to find exact tap coordinates (Flutter's semantics tree
is what `uiautomator` sees — coordinates aren't guessable from a screenshot
alone reliably), and drove the full flow: Profile → GTFS import page → "Pilih
file GTFS (.zip)" → Android's real Storage Access Framework picker → select
→ import. The page correctly showed "3 stasiun GTFS statis tersimpan. Impor
terakhir: 1 jalur, 2 trip, 6 jadwal perhentian, 1 kalender layanan." —
exactly matching the pushed feed's contents.

**A real dependency-version gotcha hit and fixed along the way**:
`file_picker`'s version is constrained by the win32 conflict between
`file_picker >=8.3.3 <12.0.0-beta.1` (win32 ^5.9.0) and this project's
`geolocator` (needs win32 ^6.0.0 transitively via `package_info_plus`) — `pub`
resolved to the old `file_picker: 3.0.4`, whose bundled Android
`build.gradle` calls `jcenter()`, a repository removed from modern Gradle/AGP
— `assembleDebug` failed immediately with "Could not find method jcenter()".
**Fix: pin `file_picker: ">=12.0.0-beta.1 <13.0.0"` explicitly** (resolved to
`12.0.0-beta.7`) rather than letting `pub`/`flutter pub add` silently pick
the older, AGP-incompatible version that technically satisfies the range.
Note this beta's API is `FilePicker.pickFile(...)` (static, singular, returns
one `PlatformFile?`) and `PlatformFile.readAsBytes()` — not the older
`FilePicker.platform.pickFiles(...)` / `.bytes` instance API.

**A real `flutter run` gotcha hit while verifying this on the emulator**:
launching via `flutter run -d <device> --debug` through a piped/backgrounded
non-interactive shell builds and installs the app, then the `flutter run`
process itself exits shortly after (no TTY to hold it attached) — and
exiting `flutter run` **kills the app it just launched** (`ActivityManager:
Killing ... remove task`), which looks exactly like a crash if you only
check `adb logcat` for exceptions (there are none). **Fix for scripted/agent
verification: don't use `flutter run` at all** — `flutter build apk --debug`,
then `adb install -r build/app/outputs/flutter-apk/app-debug.apk`, then
`adb shell am start -n <package>/<package>.MainActivity`. This installs and
launches the app as its own independent process, unaffected by whatever
tool attached it.

**A real bug found and fixed via this same live-testing pass** (unrelated to
GTFS, just discovered along the way): `ProfilePage`'s header used
`CircleAvatar(radius: 28, child: TkLogo(size: 36))` — but `TkLogo` defaults
to `showLabel: true`, rendering an inline "Teman Kereta" wordmark next to the
icon (correct for the Home/Onboarding app bars, where `TkLogo` is actually
used with the default). Squeezed into a 56px-wide avatar, that wordmark
overflowed horizontally ("RIGHT OVERFLOWED BY 124 PIXELS") and visually
bled into the adjacent "Mode tanpa akun" text. Fixed by passing
`showLabel: false` — matches how `AppUpdatePage` already (correctly) used
`TkLogo` icon-only. Verified fixed via the same emulator screenshot method.

### Bundled real feed auto-import (`GTFS_STATIC_ENABLED`)

Round 9: a genuine KRL Jabodetabek GTFS Schedule feed (`assets/gtfs/
gtfs-krl-jabodetabek-dev.zip` — labeled by its own source as dev/test
coordinates, "verify before production", but otherwise a real, complete
feed: 84 stations, 6 lines/routes, 985 trips, ~16,200 stop_times rows)
appeared bundled in the project. Wired it up for real rather than leaving
it inert:

- `AppEnvironment.gtfsStaticEnabled` / `gtfsStaticZipPath` (new
  `bool.fromEnvironment`/`String.fromEnvironment` fields, reading
  `GTFS_STATIC_ENABLED`/`GTFS_STATIC_ZIP_PATH`) gate a one-time bootstrap in
  `main.dart`: if enabled and `gtfsStopCount() == 0` (nothing imported yet,
  whether via this bootstrap or the manual "Impor jadwal GTFS" page), load
  the bundled asset via `rootBundle.load(...)` and hand it to the same
  `GtfsStaticImporter` the manual import page uses. Best-effort — any
  failure (missing/corrupt asset) is swallowed and just leaves the existing
  Data Demo fallback in place, never blocks app startup.
- `main.dart` now constructs `AppDatabase()` once itself (previously only
  `appDatabaseProvider` did, lazily) and passes that same instance into
  `ProviderScope` via `appDatabaseProvider.overrideWithValue(...)` — needed
  so the bootstrap-time import and the rest of the app share one DB
  connection rather than opening two.
- **Verified for real on the Android emulator**: fresh install (data
  wiped) → onboarding → home page. `GtfsImportPage` confirmed "84 stasiun
  GTFS statis tersimpan" after first launch, with zero manual interaction —
  the auto-import ran during `main()` before the first frame.
- **Found and fixed a second real bug via this same pass**: `HomePage`
  rendered `const DemoDataBanner()` unconditionally — so even with real
  imported GTFS data now flowing through `departuresProvider`, the page
  still claimed "Data Demo • Bukan informasi operasional". Fixed by
  checking `departures.value?.firstOrNull?.isDemo ?? true` (defaults to
  showing the banner while data is still loading/unknown, consistent with
  "never claim real when unsure"). Verified via a before/after screenshot
  pair on the emulator: banner present with `TRANSIT_PROVIDER=gtfs` before
  any import, gone once the real feed was imported and `Departure.isDemo`
  came back `false` from `GtfsStaticScheduleProvider`.

## Admin panel (`admin/`, Next.js — PRD §36)

Real, not a stub — built round 8, verified end-to-end against a running
Supabase stack via raw HTTP (`curl`, replicating the exact multipart
encoding Next.js Server Actions use for progressive enhancement, since this
is a script/agent environment without a browser): login → dashboard render
→ create an operator → confirm it persisted → confirm it appears in the
audit log → delete it → confirm it's gone. All of that worked on the first
real attempt.

**Architecture**: every read/write goes through the Supabase **service-role**
key (`lib/supabase/service.ts`), never the anon/authenticated client —
mirrors this project's existing "reference data writes need a trusted
server connection, not a client" rule. The real authorization boundary is
`verifyAdminSession()` (`lib/dal.ts`): being signed in via Supabase Auth is
not enough, the user's id must also be a row in a new `public.admin_users`
table (checked server-side, never via a client-visible RLS policy).
`proxy.ts` (Next.js 16 renamed `middleware.ts` → `proxy.ts` — the file
convention changed, functionality didn't) only does the *optimistic*
redirect-when-signed-out check that Next.js's own auth guide recommends;
it is deliberately not the real gate. Every mutation logs to a new
`public.audit_log` table right after it succeeds (PRD's "Audit log"
requirement) — see `admin/README.md` for the full "what's real vs.
deferred" breakdown (short version: operators/lines/stations/service
alerts/user-report moderation/settings/GTFS import/destinations all work;
notification composing is not built — there's no real push-notification
dispatch infrastructure to send through, and a form with nothing behind it
would violate the "no non-functional buttons" rule the Flutter app already
follows).

**Round 10 update**: Operators, Lines, and Stations all now have real edit
pages (`/operators/[id]/edit`, `/lines/[id]/edit`, `/stations/[id]/edit`),
not just create+delete — closes the gap flagged the round this panel was
built. Stations' edit page replaced the old list-page inline
facilities-only editor with a full form (code/name/coordinates/wheelchair
access/facilities), so `updateStationFacilities` was removed rather than
left as dead code alongside the new `updateStation`. Verified via the same
curl-replay technique for all three: fetched the edit form, confirmed real
seeded values pre-filled, submitted a change, confirmed it persisted, then
reverted back to the original seed value each time (**a station edit
verification pass caught its own bug**: the first revert attempt forgot the
`wheelchair_accessible` checkbox field — HTML checkboxes only submit when
checked, so omitting it silently flipped `true` → `false` — caught by
checking the list page afterward and showing "Tidak" where "Ya" was
expected, then fixed with a second, complete revert). Also removed the
unused `.env` entry from `pubspec.yaml`'s Flutter `assets:` list (flagged
as a latent risk two rounds ago — nothing ever read it via `rootBundle`, so
it was a no-op that would only become a real problem the day a genuine
secret landed in that file).

Schema additions: `supabase/migrations/20260805130000_admin_panel.sql` adds
`admin_users`, `audit_log`, `app_config` (for "Mode maintenance" / "Remote
configuration" — **the Flutter app does not read `app_config` yet**, so
toggling it in the admin panel has no effect on mobile until that read path
is built).

Bootstrap a local admin account: `node admin/scripts/bootstrap-admin.mjs
<email> <password>` (uses the Supabase Admin API, not hand-rolled password
hashing).

**Round 11 update — GTFS import** (`/gtfs-import`, `admin/lib/gtfs/`):
closes the last major gap from the panel's original build. This is a
*different* importer from the Flutter app's (`gtfs_static_importer.dart`,
which only caches a feed on-device) — this one writes into the real
reference schema (operators/lines/stations/trips/stop_times) that
`local_supabase` and other real consumers read from. Ported the CSV/GTFS
parsing logic from the Dart implementation (`admin/lib/gtfs/csv.ts`,
`parser.ts` mirror `gtfs_schedule_parser.dart`'s algorithm) rather than
pulling in a CSV dependency, so quoting/escaping behavior stays predictable
and consistent between the two importers.

The real design problem: `public.trips.service_date` is a concrete date
column (see docs/backend-local.md's "Catatan waktu GTFS"), not a recurring
pattern — but GTFS `calendar.txt`/`calendar_dates.txt` describes a
*recurring* schedule. The importer resolves this by materializing the
calendar into concrete `(trip, service_date)` rows for an admin-chosen
window (1–30 days, capped to keep row counts sane — trips × days
multiplies fast). Stations upsert by `code` (GTFS `stop_id`), lines upsert
by `code` (GTFS `route_id`) scoped to whichever operator the admin selects
in the form — GTFS has no concept of this schema's `operators`, so an
operator must already exist to attach a feed to.

**A real bug found and fixed via direct Postgres testing, not just app-level
testing**: `trips_external_service_unique_idx` is a *partial* unique index
(`where external_trip_id is not null`). A plain `.upsert(rows, {onConflict:
'line_id,external_trip_id,service_date'})` — what supabase-js generates —
cannot target it; PostgREST has no way to add the index's `where` predicate
to the `ON CONFLICT` clause it emits. Confirmed by running the exact upsert
directly via `psql` first: `ERROR: there is no unique or exclusion
constraint matching the ON CONFLICT specification`. Fixed with a new SQL
function, `public.import_gtfs_trips(jsonb)` (migration
`20260805150000_gtfs_import_function.sql`), that spells out the full
`on conflict (...) where external_trip_id is not null do update ...`
clause and returns the upserted rows' ids in the same round trip — called
via `supabase.rpc()`. Hit a second real bug while first testing this
function directly: naming the `returns table` OUT parameters
`external_trip_id`/`service_date` (matching the target table's column
names) made them ambiguous with the actual table columns inside the
function body's `on conflict` clause (`ERROR: column reference
"external_trip_id" is ambiguous`) — fixed by prefixing the OUT parameter
names (`out_external_trip_id`, etc.), which the Node code reads back
accordingly.

**Verified for real, not just compiled**: uploaded the real bundled KRL
Jabodetabek feed (`assets/gtfs/gtfs-krl-jabodetabek-dev.zip`, same file the
Flutter app auto-imports — see Round 9) via curl to the running admin panel
with a 3-day window. Result: 84 stations, 5 lines, 984 trip patterns → 2,952
dated trip rows and 48,585 stop_time rows, all landing correctly (spot-
checked one trip's stop sequence directly against the source CSV — matched
exactly). Then **re-ran the identical import and confirmed the row counts
didn't change** — the upsert-based design is genuinely idempotent, not
just "doesn't error twice."

**Incidental discovery while verifying**: found a real "KAI Commuter"
operator with 5 lines already in the local dev database, created
independently by the user (timestamp predates this round's work) — not
something I created or should touch. Worth remembering: don't assume every
row in a shared dev database was put there by this session; check
`created_at`/provenance before treating something as your own test data to
clean up.

## Hosted Supabase project (in addition to local dev)

As of this round, this project also points at a real hosted Supabase
project (not just the local stack) — a deliberate choice made after
explicit confirmation, since it's a real architecture shift away from the
"local-only" guarantee this codebase enforced everywhere before. The root
`.env` now has `APP_ENV=remote` (not `local`) and real
`SUPABASE_URL`/`SUPABASE_ANON_KEY` values — `AppEnvironment.
validateLocalOnly()` is unchanged code-wise; it simply becomes a no-op once
`APP_ENV` isn't `local` (that's exactly what it was designed to do — see
its own doc comment). Verified the Flutter app boots cleanly against this
real project on the Android emulator (installed via `adb`, checked
`logcat` for exceptions — none).

Build/run with the real config via Flutter's built-in
`--dart-define-from-file=.env` flag (reads `.env`-style `KEY=value` files
directly as compile-time defines — no code changes needed, this is a
stock Flutter CLI feature, not something built for this project).

**Resolved**: the user applied all migrations to the hosted project
manually (the direct `npx supabase db push --db-url ...` connection string
never got fixed here, and that's fine — they had their own path). Confirmed
via direct REST calls with the hosted project's service-role key that
`admin_users`, `app_config` (with its seeded `maintenance_mode`/
`remote_config` rows), `audit_log`, and the `import_gtfs_trips()` function
all exist there — i.e. the base schema, the admin_panel migration, *and*
the GTFS import function migration are all applied, not just the base
schema.

The admin panel's `admin/.env.local` now points at the hosted project
(previously local-only) — bootstrapped a real admin account there
(`node scripts/bootstrap-admin.mjs`, same email as the local one for
consistency) and verified login → dashboard → operators list all render
real hosted data after restarting the dev server (env vars are read once
at Next.js startup, so an `.env.local` edit needs a restart to take
effect — killed the old `next dev` process by its port-3000 PID and
started a fresh one). The local Supabase stack's credentials are still in
`.env.local.example` if this ever needs to point back at local dev.

**Also flagged, not yet resolved**: `pubspec.yaml` bundles the root `.env`
as a Flutter asset. That doesn't currently do anything (nothing reads it
via `rootBundle` — `--dart-define-from-file` is a build-time mechanism,
completely separate from asset bundling) but is worth removing if it's not
going to be used for a real runtime-config-reload feature, since a bundled
`.env` ships as a plain-text file inside the APK — fine while it holds only
a publishable anon key, but a real risk the day anything more sensitive
ends up in that file.

### Nearby places (destinations) admin UI

`/nearby-places` — create/edit/delete places around a station (PRD §36
"Kelola destinasi"). Verified via curl against the real hosted project:
created a test place, confirmed it appeared with the correct station join,
deleted it, confirmed removal. Edit page verified against a real seeded
place ("[DATA DEMO] Taman Contoh") — pre-filled correctly.

## Release signing

`android/app/build.gradle.kts`'s `release` build type signed with the debug
key until Round 18 (the stock Flutter-generated TODO, never replaced) —
meaning every "release" build up to that point was not a real release
artifact. Fixed with a genuine upload keystore:

- `android/app/upload-keystore.jks` — PKCS12, alias `upload`, 2048-bit RSA,
  10,000-day validity (until 2053). **Not committed** — `*.jks` is already in
  the root `.gitignore`.
- `android/key.properties` — `storePassword`/`keyPassword` (a PKCS12
  keystore requires these to be identical; `keytool` silently enforces this
  even if you pass two different values, confirmed while generating it) /
  `keyAlias` / `storeFile`. **Not committed** — `android/key.properties` is
  already in the root `.gitignore`.
- `build.gradle.kts` now loads `key.properties` (via `rootProject.file(...)`,
  which resolves to `android/key.properties` since `android/` is the Gradle
  root project for a Flutter Android module) and defines a real `release`
  `signingConfig` from it. **Falls back to debug signing with a logged
  warning when `key.properties` is absent** (a fresh checkout without the
  keystore, or CI) so the build never hard-fails — but that fallback path is
  explicitly *not* a real release artifact, and says so in the warning.

**Verified 2026-08-05**: `flutter build apk --release` completed
(`build/app/outputs/flutter-apk/app-release.apk`, ~102MB) and
`apksigner verify --print-certs` confirms its certificate SHA-256
(`65:c7:ba:1e:...:e5:6e:dc6`) exactly matches `keytool -list -v` on
`upload-keystore.jks`, and is a completely different fingerprint from this
machine's debug keystore (`9a:24:7f:fc:...`) — genuinely release-signed,
not a debug-signed artifact wearing a release label.

**Not done / left to the user**:
- **Back up `android/app/upload-keystore.jks` and `android/key.properties`
  somewhere durable** (password manager, encrypted archive) — losing this
  keystore before Play App Signing is enabled means losing the ability to
  publish updates under the same app identity. Since Google Play now manages
  the actual distribution signing key separately once Play App Signing is
  opted into (this keystore only signs the *upload*, not what end users
  install), a lost upload key is recoverable by contacting Google Play
  support with proof of ownership — but that's a slow, painful path, not a
  substitute for backing it up now.
- The certificate's Distinguished Name (`CN=Teman Kereta, OU=Teman Kereta,
  O=Teman Kereta, L=Jakarta, ST=DKI Jakarta, C=ID`) is a placeholder, not a
  registered legal entity — fine for the upload cert (Google doesn't
  validate it), but worth knowing it's there before anyone assumes it's
  real business registration data.
- iOS signing (provisioning profiles, distribution certificate) is
  untouched — this project has no iOS release path evaluated at all so far,
  Android-only.

## Known gaps (don't claim these are done)

- No general multi-transfer trip router. As of Round 16, both providers
  (`local_supabase` via `search_one_transfer_trips`, `gtfs` via
  `GtfsStaticScheduleProvider._oneTransferTrips`) handle direct trips *and*
  single-transfer trips, but neither handles a journey needing 2+ changes —
  still returns nothing rather than a wrong answer for those pairs.
- Test coverage: unit tests (state machine, confidence engine,
  nearest-station math) + Drift round-trip tests (in-memory DB) + a
  `local_supabase` integration test that runs against a real Supabase stack
  (`test/integration/supabase_transit_provider_live_test.dart`, gated behind
  `--dart-define=LIVE_SUPABASE=true`) + real widget tests for the widget
  smoke test, `GtfsImportPage` (empty/imported/error states), and
  `RideDetectionConfirmPage` (empty/soft-ask/strong-tier states). Still no
  broader integration tests (e.g. full navigation flows end-to-end) beyond
  what's listed here.
- Gojek/Grab deep link **strings** are still unverified against live/current
  documentation (no access to the real apps to confirm `gojek://`/
  `grab://open` actually route anywhere useful) — but the launcher's own
  fallback *logic* (try the scheme, fall back to the Play Store listing when
  the app isn't installed) is now unit-tested with a fake
  `UrlLauncherPlatform` (`test/core/ride_hailing_launcher_test.dart`), so
  that part is no longer "untested," just "scheme correctness unverifiable
  without the real apps."
- Crash monitoring is wired (see "Crash monitoring (Sentry)" above) but
  never verified against a real Sentry project/DSN — compile/analyze-only.

## Local dev environment notes (this machine specifically)

- Flutter SDK: `~/develop/flutter/bin` — not on `PATH` by default.
- Android SDK/Studio installed; `JAVA_HOME` is **not** set by default —
  export `JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"` before
  running `gradlew` directly (Flutter's own build wraps this correctly on
  its own; only matters for manual `./gradlew` calls).
- `python` (not `python3`) has PIL installed, for any future image work.
- `docker` CLI is installed (v29.6.2); Docker Desktop's daemon isn't running
  by default but its exe is at
  `C:\Users\<user>\AppData\Local\Programs\DockerDesktop\Docker Desktop.exe`
  (not the more common `C:\Program Files\Docker` path) — launch it and poll
  `docker ps` until it responds, then `npx supabase start` brings up the full
  local stack for real `local_supabase` verification.
- An Android emulator (AVD id `Keenan`) is available —
  `flutter emulators --launch Keenan`, then poll `adb devices` /
  `adb shell getprop sys.boot_completed` until ready. `adb`/`platform-tools`
  are at `~/AppData/Local/Android/Sdk/platform-tools`, not on `PATH` by
  default either. This makes genuine on-device UI verification possible —
  see the GTFS import UI section above for the full recipe (build APK +
  `adb install` + `adb shell am start`, not `flutter run`, which gets killed
  when its own process exits in a non-interactive shell). Git Bash mangles
  any `adb` argument starting with `/` (e.g. `/sdcard/...`) into a Windows
  path — prefix with an extra `/` (`//sdcard/...`) to stop MSYS from
  rewriting it, for both `adb push`/`pull` and `adb shell` commands.
- This project is **not a git repo** — no diff/history safety net. Save
  early, check file state before trusting an in-context read of anything
  another process might also be touching.
- When backgrounding a long Gradle build, don't pipe it through
  `tail -N` (no `-f`) — that buffers all output until the process exits, so
  a genuinely-still-running build is indistinguishable from a hung one.
