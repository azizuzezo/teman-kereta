# ENGINEERING.md — Teman Kereta implementation notes

This file tracks **what is actually wired up and working today**, as opposed to
what `PRD.md` asks for. Read `PRD.md` for requirements; read this file for
ground truth on the current codebase. Update it whenever a flow goes from
"exists" to "actually connected end-to-end," or when something here turns out
to be stale.

Last verified: 2026-08-05. `flutter analyze` clean (no errors). `flutter
test` — 67/67 passing + 1 skipped (the live-Supabase integration test)
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

### Geofence-confirmed auto-advance (Round 18 — combines the schedule estimate with the rider's own real GPS)

Until Round 18, `advanceStop()` only ever ran from one place: a manual
"Lanjut" tap on `active_trip_page.dart` — the whole "stations remaining"
countdown was pure schedule/button-tapping, with zero positional
confirmation once a trip was `onBoard`. Requested explicitly: make the
estimate work well *combined with the rider's own GPS*, without violating
the project's own established "no continuous GPS" posture (PRD §31) or the
"GPS being unreliable must never produce false information" rule (PRD §37
Skenario 3).

The fix reuses the exact geofencing infrastructure already built for ride
detection, applied to the CURRENT trip's own route instead of saved home/
work/favorite stations:

- `ActiveTripController._syncRouteGeofences()` re-scopes the native geofence
  set to the stations still ahead (`trip.stationIds` from
  `currentStationIndex + 1`, capped at 20 to match
  `StationGeofenceManager.MAX_STATION_GEOFENCES` — a passed station is
  dropped from the scope, so a long multi-transfer route never approaches
  the cap). Called from `start()` and after every `advanceStop()`.
- `ActiveTripController.checkGeofenceProgress()` reads the same
  `getLastGeofenceEvent()` native call `RideDetectionController` already
  polls, and calls `advanceStop()` automatically the moment a real ENTER
  event fires for `session.nextStationId` specifically — not just any
  geofence event, and not `exit`/`dwell`. Station sequence/schedule stays
  the actual source of truth either way: a missed or stale geofence event
  just means the rider taps "Lanjut" manually (still fully functional),
  never a wrong "stations remaining" count.
- `RideDetectionWatcher` (renamed in spirit, not in code — see its updated
  doc comment) now drives *either* consumer off the same 25s timer:
  `ActiveTripController.checkGeofenceProgress()` while a trip is confirmed,
  or `RideDetectionController.checkNow()` otherwise. The two never run at
  once — `RideDetectionController.checkNow()` already stood down on its own
  the moment a trip is confirmed (pre-existing), and now the *native*
  geofence scope itself is also exclusively owned by whichever one is
  active, never both.
- **Real interaction handled**: native geofence registration *replaces* the
  whole scope (see `StationGeofenceManager`'s own doc comment — this was
  already true before Round 18, just never mattered until two features
  needed the same scope). So `ActiveTripController._releaseRouteGeofences()`
  (called from `cancel()`/`complete()`) unregisters the trip's route
  geofences and then calls the new
  `RideDetectionController.reregisterSavedStationGeofences()` — otherwise
  finishing a trip would silently leave ride detection with zero geofences
  until the user re-toggled the setting off/on. `enable()` was refactored to
  call that same new method instead of duplicating the registration logic.

**Verified**: 5 new tests in `test/features/active_trip_controller_test.dart`
(`checkGeofenceProgress` group) using, for the first time in this test
suite, a mocked native `MethodChannel`
(`TestDefaultBinaryMessengerBinding...setMockMethodCallHandler`) to feed a
controlled `getLastGeofenceEvent()` response — previously every native-
channel call in tests silently no-op'd via `MissingPluginException`, which
was enough for existing tests but can't exercise this feature's actual
logic. Covers: a matching ENTER event advances the trip; a different
station's event does nothing; `exit`/`dwell` transitions do nothing; a
repeated (already-processed) event doesn't double-advance; nothing happens
before a trip exists. Full suite 67/67 passing, `flutter analyze` clean.

**Not done**: no on-device verification this round (would need two phones/
an emulator geofence trigger plus a real confirmed trip walked through
physically or via mock location) — this is Dart-logic-verified via the
mocked channel, not hardware-verified. Round 7.6 established that on-device
geofence verification is possible on this machine's emulator; worth doing
before shipping if time allows.

## Geofence reboot recovery (Round 22)

Every prior round's "geofences don't resync on session restore" note was
slightly imprecise: Android geofence registrations are held by Google Play
services and genuinely **survive an app process kill/restart** — they are
cleared entirely only on a **device reboot**. That's the actual, narrower
gap this round closes.

- `NativeStateStore.GEOFENCE_DETAILS_JSON` — a new persisted field
  alongside the pre-existing `GEOFENCE_REGISTERED_IDS` (station ids only).
  Stores the full `{id, latitude, longitude, radiusMeters}` for the
  currently-registered scope as a JSON array (`org.json`, no new
  dependency), via new `NativeStateStore.encodeGeofenceDetails`/
  `decodeGeofenceDetails`/`geofenceDetails()` helpers.
- `StationGeofenceManager.register()`/`unregister()` now keep this JSON in
  sync alongside every existing write/removal of `GEOFENCE_REGISTERED_IDS` —
  `unregister()` filters the persisted detail list down to whatever
  `stationIds` remain, matching the existing id-set logic exactly rather
  than duplicating it.
- New `GeofenceBootReceiver.kt` listens for `android.intent.action.
  BOOT_COMPLETED`, reads `geofenceDetails()` + `GEOFENCE_EXPIRES_AT`, bails
  out silently if the scope is empty/expired or location permission isn't
  currently granted (a `BroadcastReceiver` can't prompt for permission), and
  otherwise re-registers the exact same geofence set — same transition
  types, same loitering delay, same remaining expiration window — via
  `GeofencingClient.addGeofences`. Deliberately provider-agnostic: it
  replays whatever the *last* registered scope was, whether that came from
  an active trip's route (`ActiveTripController._syncRouteGeofences`) or
  ride-detection's saved stations, without needing to know which Dart-side
  feature owned it.
- Refactored `geofencePendingIntent()` out of `StationGeofenceManager` into
  a shared `StationGeofenceReceiver.pendingIntent(context)` companion
  function, so `StationGeofenceManager` (Activity-scoped) and
  `GeofenceBootReceiver` (Context-only, no Activity available at boot) build
  the identical `PendingIntent` Play services matches transitions against —
  a geofence re-registered with a *different* `PendingIntent` would silently
  never fire.
- Registered `GeofenceBootReceiver` in `AndroidManifest.xml` with an
  explicit `<uses-permission android:name="android.permission.
  RECEIVE_BOOT_COMPLETED" />`. **Also removed the unused `workmanager:
  ^0.10.6` pubspec dependency** while investigating this — confirmed via
  grep it was never referenced anywhere in `lib/`, and it's almost
  certainly why `RECEIVE_BOOT_COMPLETED` was already showing up in earlier
  decoded release-APK manifests (transitive manifest merging) despite this
  app's own manifest never declaring it. Now the permission is declared
  explicitly, for a receiver that's actually used.

**Verified**: `flutter analyze` clean (no new issues), `flutter pub get`
resolved cleanly after removing `workmanager` (nothing depended on it), and
`flutter build apk --debug --dart-define-from-file=.env` — a real Kotlin/
Gradle compile of every file touched this round — succeeded. **Not
runtime-verified**: this machine's emulators have been unstable since Round
21 (documented there), so there was no way to actually reboot a device/
emulator with an active trip or ride-detection enabled and confirm
geofences are still monitored afterward without reopening the app. Whoever
gets a stable device next should do exactly that: enable ride detection or
start a trip, force a reboot (`adb reboot` or the emulator's power-cycle),
wait for boot to finish, and confirm (via `getRegisteredStationGeofences()`
or a real ENTER event) that the geofences are live again with no app
interaction.

**Round 22 follow-up attempt**: a later emulator session came back
genuinely responsive at first (`adb shell echo` round-tripped in 151ms), so
this round tried to close the on-device verification gaps for real —
`integration_test/app_test.dart`, this reboot-recovery fix, and the
remaining accessibility audit pages. Partway through, the exact same
degradation pattern documented in Round 21 recurred, this time **worse**:
`EGL_emulation: app_time_stats` logged **82,377ms for a single frame**
(vs. Round 21's already-severe ~30,000ms). Confirmed via the Dart VM
service (`getStack` on the paused main isolate came back empty — execution
was stuck deep in native/rendering code, not a Dart-level hang) and by
bracketing every `await` in `main()` with temporary `debugPrint` markers,
rebuilding, and watching them all print cleanly in ~5 seconds on one launch
attempt — proving the *app* isn't hanging, the *renderer* is. A manual
walk-through (fresh install → onboarding → Jadwal → search) reliably
reached the "Mencari…" (searching) state and then sat there for 60+ real
seconds while frame times were 15,000–82,000ms each, before the round
stopped waiting rather than keep polling a fundamentally degraded
environment. This makes the on-device verification for reboot-recovery,
the accessibility audit, and `integration_test` **still open**, now with
harder quantitative evidence that this is host-resource exhaustion (worse
each time it's checked), not anything in the app. See "`integration_test/`
suite" below for what this specifically means for that suite's own attempt
this round.

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

**Round 22 — real-GPS verification attempt: logic confirmed correct, but
this machine's emulator can't actually mock a real coordinate.** Walked
through onboarding for real, granting the location permission (not skipping
it, unlike every prior round's verification passes) after setting `adb emu
geo fix 106.7906 -6.595` (real Bogor station coordinates). The "Lokasi demo"
fallback correctly disappeared — confirming the real-GPS code path is what
ran, not the demo fallback — but the computed result was obviously wrong:
"Cikarang, 13963.2 km, 167626 menit jalan kaki". Investigated rather than
dismissed: `adb shell dumpsys location` showed the OS's actual last-known
fused/GPS location was `37.421998, -122.084000` — Mountain View, CA, the
Android emulator's classic default — **completely unrelated to the geo fix
command**, which reported `OK` every time but never actually updated the
location subsystem, confirmed across multiple retries (re-issuing the fix,
forcing a fresh request via the Nearby Stations page's explicit refresh
button) with zero change in `dumpsys location`'s output. The 13,963km
figure is exactly consistent with Mountain View → Jakarta-area distance,
and the walking-time figure divides back out to the expected ~5km/h
constant — meaning **the haversine math and walking-time estimate are
completely correct**, just fed a stale, wrong coordinate by this emulator's
GPS-mocking mechanism, which appears non-functional on this specific AVD/
image regardless of `geo fix` reporting success. This is a test-environment
limitation, not an app bug — real verification of this feature's accuracy
needs either a physical device or a different emulator image with working
GPS injection (the Extended Controls GUI's location tab, untested here
since this session runs headlessly). The emulator crashed entirely
(process disappeared, `adb devices` empty) shortly after this investigation
— the same instability pattern as Round 21, blocking further on-device work
(ride detection/geofence-reboot/crowd-reporting verification, remaining
accessibility audit pages) for this round too.

**Confirmed the real root cause of this session's repeated frame-time
degradation, from the emulator's own boot log**: `hasSufficientHostVulkanDriver:
unsupported Vulkan API level (1.3.215, min required: 1.3.240, vendor:
Intel(R) UHD Graphics 620)` — this dev machine's integrated GPU doesn't meet
the emulator's Vulkan requirement, so it falls back entirely to software
rendering (SwiftShader/lavapipe, `Critical: Failed to load opengl32sw...
Falling back to system OpenGL`). Software rendering is CPU-bound and
degrades badly under any concurrent load — exactly the pattern seen
repeatedly (30s/frame in Round 21, 82s/frame earlier this round). **This is
a hardware limitation of this specific machine, not fixable by any code or
config change** — a machine with a Vulkan-1.3.240+-capable GPU (or a real
physical Android device either way) would not have this problem at all.

**Immediately after this diagnosis, retried on a freshly cold-booted
emulator instance (`-no-snapshot-load`) — and got a genuine, clean
confirmation before it crashed again**: same real GPS fix, onboarding
walked through granting location permission for real, and this time Home's
nearest-station card correctly showed **"Stasiun Bogor, 0 m • 1 menit
jalan kaki"** — exactly correct, since the fix was set to Bogor's own
coordinates. This confirms the earlier stale-Mountain-View result really
was a stale Play-services fused-location cache specific to that
long-running emulator instance (open for hours across many rounds this
session) — a fresh boot cleared it, and the real-GPS code path works
completely correctly end-to-end when the OS actually cooperates. The
emulator then crashed again (segfault, exit code 139) within about a
minute of reaching Home, while navigating to Settings for the next
verification step (ride detection). **Given 5+ distinct crashes across
this session alone, all tied to the same confirmed software-rendering
root cause, further on-device verification this project needs should
happen on a physical device** — retrying this emulator again without a
different machine or a fixed Vulkan driver is very unlikely to hold up
for a multi-step flow (ride detection → geofence registration → reboot →
crowd reporting → remaining accessibility pages all still genuinely
unverified on-device, not because of any known app defect).

**One more attempt, at the user's specific request, for the single most
important untested piece** — the reboot-recovery code itself had never
been exercised at all (unlike ride detection/crowd reporting, which are
older features previously verified in earlier rounds). Before retrying,
added real observability the receiver was missing entirely: two new
`NativeStateStore` fields (`GEOFENCE_BOOT_RECOVERY_RESULT`/`_AT`,
mirroring the existing `lastGeofenceEvent` pattern this file already
uses for read-only broadcast receivers with no UI) and
`recordGeofenceBootRecovery()`/`geofenceBootRecoverySnapshot()` helpers,
written at every branch of `GeofenceBootReceiver.onReceive()`.

**A real, latent correctness bug was caught while adding this, independent
of whether the device test itself would ever complete**: `addGeofences()`
is asynchronous, but a plain `BroadcastReceiver.onReceive()` returning
gives the OS no reason to keep the process alive until that async
callback fires — Android is free to kill the process the moment
`onReceive()` returns, silently dropping the completion listener (and
the whole point of this receiver) with no error anywhere. Fixed by wrapping
the async call in `goAsync()`/`pendingResult.finish()`, the documented,
correct pattern for exactly this situation. **This means the original
Round 22 version of this receiver had a real reliability gap regardless of
the emulator issues** — worth remembering as a general lesson: adding
observability to an untested piece of async receiver code is worth doing
*before* the on-device test, not just for the test's sake, because writing
the instrumentation forces a close enough re-read of the code to catch
this class of bug.

Rebuilt (`flutter build apk --debug --dart-define-from-file=.env` —
succeeded), relaunched a fresh emulator instance, but it **crashed again
(segfault, exit code 139) within about a minute of the app reaching Home**
— before ride detection could even be enabled, let alone reaching the
reboot step. Per the user's own "try once more" framing and the plan
agreed beforehand, did not attempt a third relaunch. **Net result**: the
observability + `goAsync()` correctness fix are real, build-verified
improvements landing in this round regardless; the actual reboot-survives
end-to-end proof is still not obtained, now confirmed to need a physical
device or a different machine, not further retries here. Whoever gets a
stable device next should: enable ride detection, confirm via
`adb shell run-as id.temankereta.teman_kereta cat shared_prefs/
teman_kereta_native_state.xml` that `geofence.registered_station_details_json`
is populated, `adb reboot`, wait for boot, then check the same file for
`geofence.boot_recovery.result` — `"success"` proves the fix works
end-to-end without ever reopening the app.

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

### Crowd-sourced vehicle positions (Round 19 — real rider GPS, with consent)

User's own idea: since there's no real GTFS-Realtime feed (see the GTFS-
Realtime section above) and reverse-engineering the official app was
correctly ruled out, have consenting riders' own phones report their GPS
position while an Active Trip is confirmed `onBoard` a specific train, and
show that aggregated position to *every* user — genuinely real positions,
sourced from this app's own users with their own consent, not a third
party's infrastructure.

**Consent model** (explicit product decision, not assumed): bundled into
the existing "Deteksi Otomatis Naik KRL" setting
(`rideDetectionEnabled`) — no separate toggle. Enabling that setting is
what authorizes GPS upload during a confirmed active trip; the settings UI
subtitle (`profile_page.dart`) and `PrivacyPage` were both rewritten to
disclose this plainly, since it's a real, new exception to this app's
"nothing leaves the device" posture up to this point.

**Backend** (`supabase/migrations/20260806090000_crowd_sourced_positions.sql`):
- `public.crowd_position_reports` — insert-only for `anon`/`authenticated`
  (no select grant at all; this table is a write-only inbox), keyed by
  `(external_trip_id, service_date)` rather than `trips.id` — the one
  identifier every provider (`gtfs`/`local_supabase`) has in common,
  since a `gtfs`-provider client only ever has the raw GTFS trip_id, never
  a Supabase row UUID. A `device_session_id` (random per-install UUID,
  never tied to a real identity) exists only so the aggregation can count
  distinct reporters, not to identify anyone. A `CHECK` constraint rejects
  any report timestamped more than 10 minutes in the past or 2 minutes in
  the future outright — spoofed/backdated reports are rejected at the
  table level, not filtered out later.
- `public.refresh_crowd_vehicle_positions()` — deletes reports older than
  10 minutes (the retention window PRD §32 requires for raw location
  data) unconditionally on every call, then averages the last 3 minutes of
  reports per `(external_trip_id, service_date)` and upserts into
  `public.vehicle_positions` as `source = 'crowd_sourced'`,
  `accuracy_status = 'near_real_time'` (deliberately not `'real_time'` —
  it's delayed by polling + averaging, so calling it instant would be
  dishonest). Left-joins to `public.trips` to resolve a real `trip_id`
  when that service_date has been imported there; leaves it `null`
  otherwise rather than dropping the position. Same delete-then-insert
  idempotent pattern as `refresh_estimated_vehicle_positions()` — never
  touches other sources.
- `vehicle_positions.source`'s CHECK constraint gained `'crowd_sourced'`
  alongside the existing four values.
- `admin/scripts/refresh-vehicle-positions.mjs` now calls both refresh
  functions every tick.

**A real cross-provider modeling problem, solved**: a multi-transfer trip
has two separate physical trains (legs), so a single trip-level identifier
would be ambiguous about which leg's GPS is being reported. Fixed by moving
`externalTripId`/`serviceDate` onto `TripLeg` (not `TransitTrip`) and adding
`ActiveTripSession.currentRailLeg` — a getter that walks
`trip.transferBoundaries` against `currentStationIndex` to resolve exactly
which leg (which real train) the rider is currently on, reusing the same
index math `transferBoundaries`/`stationIds` already established (Round 1).
Both `GtfsStaticScheduleProvider` and `SupabaseTransitProvider` now
populate these fields per leg — the latter required extending
`search_direct_trips`/`search_one_transfer_trips` themselves
(`supabase/migrations/20260806093000_trip_search_external_ids.sql`, a
straight column addition to their existing SELECT lists, no logic changes)
to return `external_trip_id`/`service_date` at all.

**Reporting lifecycle** (`ActiveTripController` +
`lib/core/location/crowd_position_reporter.dart`): a 20s periodic timer
starts in `start()` (and resumes on session restore from a persisted
snapshot after an app restart), stops in
`cancel()`/`complete()`/`_markMissedDestination()`, and on
every tick re-reads `rideDetectionEnabled` **live** (`ref.read`, not
watched) rather than reactively — turning the setting off mid-trip stops
reports on the very next tick without needing to rebuild the controller.
Each tick is a one-shot `Geolocator.getCurrentPosition()` (never a
continuous stream — same posture as the rest of this app's location
handling, PRD §31), silently skipped whenever location permission isn't
granted, GTFS-RT is disabled, or the current leg has no
`externalTripId` (mock/demo data never reports, by construction).

**Hybrid read path** (`lib/data/providers/hybrid_transit_realtime_
provider.dart`): `TRANSIT_PROVIDER=gtfs` — the provider actually selected
in the committed `.env` — gets a real, visible effect from this feature
without switching to `local_supabase` for schedule data too.
`HybridTransitRealtimeProvider` merges `GtfsRealtimeTransitProvider`'s
vehicle positions (empty today, real if a feed URL ever exists) with
`SupabaseTransitProvider`'s (schedule-estimated + crowd-sourced) by
tracking each source's latest emission and re-concatenating on every
update from either side — trip updates/alerts still come from
`GtfsRealtimeTransitProvider` alone, no crowd-sourced equivalent exists for
those. Only constructed when `SUPABASE_ENABLED=true`; falls back to plain
`GtfsRealtimeTransitProvider` otherwise, avoiding
`SupabaseTransitProvider`'s own `StateError` guard.

**Verified**: the new SQL function tested locally with synthetic report
rows (correct averaging, correct idempotent re-run, correct retention
delete); the anon-key RLS path confirmed via curl (`insert` succeeds,
`select` correctly 401s with "permission denied"); `search_direct_trips`/
`search_one_transfer_trips`'s new columns confirmed via psql and via the
full `--dart-define=LIVE_SUPABASE=true` integration suite (still 6/6
passing after the signature change); 9 new unit tests
(`test/domain/active_trip_test.dart` for `currentRailLeg` at/before/after
the transfer boundary and the single-leg case;
`test/core/crowd_position_reporter_test.dart` confirming the
`SUPABASE_ENABLED` guard is a genuine no-op — true by default in every
test run, since no `--dart-define` is passed;
`test/data/hybrid_transit_realtime_provider_test.dart` confirming the
merge/latest-value-persists/trip-updates-passthrough behavior with fake
providers). Full suite 76/76 after.

**Not done**:
- **The two new migrations haven't been applied to the hosted Supabase
  project** — confirmed this the hard way: ran the updated poller script
  against `admin/.env.local` (which points at hosted) and got "Could not
  find the function public.refresh_crowd_vehicle_positions" — expected,
  since the user applies migrations to hosted themselves (same process as
  every prior migration this session), just worth flagging explicitly
  since this feature is otherwise fully wired.
- No on-device verification of an actual GPS report reaching the table —
  verified the SQL/RLS/aggregation layers thoroughly and the Dart logic via
  mocks/fakes, but never walked a real device through a real active trip
  with location permission granted to confirm an actual row lands in
  `crowd_position_reports`.
- ~~No rate limiting or abuse hardening~~ **Closed in Round 22** — see
  `supabase/migrations/20260806100000_crowd_report_rate_limit.sql`: a
  per-`device_session_id` insert rate limit (max 1 report/15s, checked via
  a `security definer` function inside the existing insert RLS policy's
  `with check`) plus a coarse geographic bounding box derived from the
  bundled feed's real station coordinates (lat -6.8..-5.9, lon
  106.0..107.35 — padded from the actual min/max found in `stops.txt`).
  **Verified against the local stack**: applied via `psql`, then 3 curl
  calls through the real anon-key PostgREST path — a valid report inside
  the box succeeded (201), an immediate second report from the same
  `device_session_id` was rejected (401, rate limit), and a report outside
  the box was rejected (401, geography check). **Known, stated limitation**:
  this doesn't stop an attacker who generates a fresh random
  `device_session_id` per request — that field is unauthenticated
  client-supplied data, the same gap every anon-key-only architecture has
  without device attestation (Play Integrity/App Check — deliberately not
  part of this project, no Firebase anywhere). Real protection against a
  determined attacker needs that, or Supabase gateway-level rate limiting
  (an infra/dashboard setting, not something a migration can express).
  **Not yet applied to the hosted project** — this migration was written
  after the two Round 20 migrations the user already applied to hosted, so
  it's a new manual-apply step, same as always.
- Airport Rail Link / KA Lokal Merak (Round 19's other finding) still
  have no schedule data at all, so they can never produce a crowd position
  either — moot until that gap is addressed.

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

### Two real stations were missing from the bundled feed — found via the official route map, now fixed

The user shared the actual, official PT KAI Commuter "Peta Rute Jabodetabek
& Merak" route map. Rather than filing it away, cross-checked every one of
this feed's 5 lines against it station-by-station — a genuine correctness
pass against an authoritative source, not just trusting the feed's own
"verify before production" disclaimer forever. Result: **the station SET,
ORDER, and interchange structure for all 5 lines matched the real map
almost exactly** (a real credit to however this dev feed was originally
built) — with exactly two concrete, confirmed omissions:

- **Jatake** — a real station on the Rangkasbitung line between Cicayur
  (`CC`) and Parung Panjang (`PRP`), visible on the map but entirely absent
  from `stops.txt`/`stop_times.txt`.
- **Jakarta International Stadium (JIS)** — a real station on the Tanjung
  Priok line between Kampung Bandan (`KPB`) and Ancol (`AC`), same
  situation.

Fixed directly in the bundled asset (`assets/gtfs/
gtfs-krl-jabodetabek-dev.zip`) via a one-off Python script (not committed —
lived in the scratchpad): added both stops to `stops.txt` (same
`"Approximate coordinate for development/testing; verify before
production."` disclaimer as every other stop in this feed — their
coordinates are still visual-map estimates, not surveyed), then for every
trip on the affected route (`RANGKAS`/`PRIOK`) found the adjacent
`PRP`↔`CC` or `KPB`↔`AC` stop_time pair and inserted a new row at the
time-weighted midpoint between them, renumbering `stop_sequence` for every
subsequent stop on that trip. **190 of 202** Rangkasbitung trips and **all
64** Tanjung Priok trips got the insertion — the other 12 Rangkasbitung
trips are legitimate short-turn services that never traverse that segment
at all (verified individually, not just assumed), so their exclusion is
correct, not a bug.

**Verified thoroughly, not just "the script ran"**: row-count arithmetic
checked exactly (84+2=86 stops, 16,195+254=16,449 stop_times, both matching
the insertion counts precisely); the existing GTFS test suite still 22/22
(all synthetic-fixture-based, unaffected by this change, as expected); and
— the real check — imported the actual post-fix zip into an in-memory
Drift DB via a throwaway test and confirmed a real `THB` → `RK` trip search
resolves with `JTK` correctly sequenced between `CC` and `PRP` in the
station list (`[..., CSK, CC, JTK, PRP, CJT, ...]`). Full app suite still
67/67 after the change.

Station/trip counts cited elsewhere in this file (Round 9's "84 stations,
985 trips", Round 12's admin-panel-import "84 stations") predate this fix
— now **86 stations**, same 984/985 trip count (no new trips, just two new
stops inserted into existing ones). `admin/` has no separate copy of this
feed to also fix (its GTFS import is upload-driven, not a bundled test
asset), so this was a single-location correction.

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

## Admin panel hosting (Round 22 — Vercel misconfiguration found, then migrated to Cloudflare Workers)

The project is now version-controlled (`git` at the repo root, remote
`https://github.com/azizuzezo/teman-kereta.git`). The user had pushed it
intending to host the admin panel at `temankereta.web.id`, but reported the
domain "tidak terbuka" (won't open).

**Initial diagnosis — real, but incomplete**: `nslookup temankereta.web.id`
(apex) returned no DNS record at all. But `www.temankereta.web.id` DID
resolve (CNAME to a `vercel-dns` host) and TLS worked — it just 404'd, even
at the raw `https://temankereta.vercel.app` URL with `X-Vercel-Error:
NOT_FOUND`. Investigating with the Vercel CLI (which auto-authenticated via
an already-approved browser session on this machine — worth knowing, since
the same thing happened with `wrangler`/Cloudflare moments later) found the
real cause: a project named `temankereta` already existed, correctly linked
to both `temankereta.web.id` and `www.temankereta.web.id` as domains, but
its environment variables were the **Flutter app's** `.env` values
(`APP_ENV`, `TRANSIT_PROVIDER`, etc.) — not the admin panel's actual
required vars (`NEXT_PUBLIC_SUPABASE_URL`/`NEXT_PUBLIC_SUPABASE_ANON_KEY`/
`SUPABASE_SERVICE_ROLE_KEY`, from `admin/.env.local.example`). The project's
dashboard "Root Directory" was also apparently never set to `admin`,
producing a build with no matching routes — `NOT_FOUND` on every path,
including the bare `.vercel.app` URL, independent of DNS entirely.

Corrected the env vars (added the 3 real ones for Production+Preview) and
confirmed the Root Directory theory directly: deploying via CLI from
`admin/` failed with `path "...\admin\admin" does not exist` (Vercel
appended its dashboard-configured `admin` root onto the CLI's own `admin`
cwd) — deploying from the repo root instead would have been the fix, but
**Claude Code's own safety classifier blocked that specific command**,
since uploading the *whole* repo root (Flutter source, the release
keystore, `.env`) to a third-party host is a meaningfully bigger action
than deploying just `admin/`. This was surfaced to the user rather than
worked around, per the classifier's own guidance.

**User chose to switch to Cloudflare Workers instead** (a real tradeoff
discussion, not a snap decision — Cloudflare was picked knowing it needed
a bigger lift: adapting Next.js Server Actions to a different runtime,
with real risk of something subtly breaking). Rationale: the domain's
nameservers were already Cloudflare's (`clay.ns.cloudflare.com`/`marjory.
ns.cloudflare.com`), and `wrangler` had `pages/workers (write)` scope
already authenticated.

**The actual migration** (Next.js 16.3.0, confirmed compatible via the
newer `@opennextjs/cloudflare` adapter — the `@cloudflare/next-on-pages`
package is the older, now-secondary path):
- `npm i @opennextjs/cloudflare@latest` + `wrangler@latest`, new
  `wrangler.jsonc` (`compatibility_flags: ["nodejs_compat"]`, required
  `compatibility_date >= 2024-09-23`) and `open-next.config.ts`.
- Audited `admin/lib`/`admin/app` for Node-only APIs (`fs`/`crypto`/`path`/
  `Buffer`/`require`) first — found none, a clean starting point.
- **Real, documented incompatibility hit and fixed**: Next.js 16's new
  `proxy.ts` convention (the renamed `middleware.ts`) is **hard-locked to
  the `nodejs` runtime — `edge` cannot be configured**, and OpenNext's
  Cloudflare adapter doesn't support Node.js middleware yet (`ERROR Node.js
  middleware is not currently supported`). Per Next.js's own migration
  docs: `middleware.ts` is still supported specifically for cases that need
  `edge` — reverted `proxy.ts` back to `middleware.ts` (same logic, just the
  file/export name), since this auth check only touches cookies and a
  fetch-based Supabase client, genuinely edge-compatible. This fixed the
  build.
- **A second, subtler bug found and fixed**: `@supabase/supabase-js`
  defaults to the `cross-fetch` polyfill outside a real browser, which
  doesn't work correctly under Workers' native fetch — a documented,
  known issue (see supabase/supabase-js and supabase/discussions#588).
  Added `global: { fetch }` (the native global) to every server-side
  Supabase client construction (`lib/supabase/server.ts`,
  `lib/supabase/service.ts`, and `middleware.ts`'s inline client) —
  `lib/supabase/browser.ts` needed no change since it already runs in a
  real browser.
- Deployed via `npx opennextjs-cloudflare deploy` → live at
  `https://temankereta-admin.si-aziz6970.workers.dev`. Set the 3 required
  Supabase env vars as **Worker secrets** (`wrangler secret put`, values
  piped from `admin/.env.local` without ever being echoed to the terminal).
- **A false alarm along the way, worth remembering**: the curl-replay
  technique used throughout this project to verify Next.js Server Actions
  (established Round 8) returned a 500 ("Connection closed", a
  `node-internal:streams_writable` stack) when replaying the login form.
  Spent real effort chasing this — checked whether it was the cross-fetch
  bug (ruled out: middleware's own Supabase call had already succeeded
  *before* that fix, via a clean redirect), searched for a known OpenNext
  Windows-build issue (the adapter does warn "not fully compatible with
  Windows... could encounter unpredictable failures" on every build, which
  looked like a strong candidate). **The user tried the real login in an
  actual browser and it worked immediately** — screenshot confirmed
  successful login, sidebar navigation, and the GTFS Import page rendering
  real content. The likely explanation: Next.js Server Actions check the
  request's `Origin` header as CSRF protection, and a raw `curl -F`
  multipart replay doesn't send one — this project's curl-replay technique
  may need an explicit `-H "Origin: https://<host>"` from now on against
  newer Next.js versions. **Lesson**: when a verification technique that
  worked reliably in the past suddenly fails on a new deployment target,
  checking with a real client (here, literally asking the user to try their
  own browser) is faster and more conclusive than chasing the failing
  technique's own stack trace indefinitely.

**Custom domain — `www` done, apex still blocked**: Cloudflare Workers'
"Custom Domain" feature (`wrangler.jsonc`'s `routes: [{pattern, custom_domain:
true}]`) auto-manages the DNS record itself when the zone is already on
Cloudflare nameservers — no manual A/CNAME record needed, unlike Vercel.
Attempting both `temankereta.web.id` and `www.temankereta.web.id` at once
partially failed: `www` briefly went to NXDOMAIN (alarming, but transient —
confirmed via `nslookup` against `clay.ns.cloudflare.com` directly, the
zone's actual authoritative nameserver, that the record existed correctly;
public resolvers just hadn't caught up yet) and now genuinely works
(`https://www.temankereta.web.id/login` → 200, confirmed with `curl
--resolve` to bypass DNS entirely). The **apex** (`temankereta.web.id`)
consistently fails with `Hostname 'temankereta.web.id' already has
externally managed DNS records (A, CNAME, etc). Delete them first` — some
existing record now sits in the zone (resolves to Cloudflare's own proxied
IPs, but returns 403 — no Worker route is actually attached to it) that
Wrangler's OAuth token, scoped to `zone (read)` only, can't remove. **This
needs the user to open the Cloudflare dashboard's DNS tab for
`temankereta.web.id`, delete whatever record exists for the bare apex
hostname (not `www`), then the apex custom domain can be re-attempted** —
deliberately not worked around by extracting the OAuth token for raw API
writes, since that scope boundary (read-only) looks intentional.

**A transparency note worth keeping**: both `vercel whoami` and `wrangler
whoami` silently completed a full OAuth device-flow login mid-session
(via an already-approved browser session on this machine) without any
explicit prompt — flagged to the user immediately both times, since these
are real actions against real external accounts, not something to use
quietly just because the CLI made it frictionless.

## Real device feedback round: admin panel bugs, a broken hosted import, TRANSIT_PROVIDER switch, first-pass account login

The user tested on an actual physical Android device for the first time
and reported multiple real issues in one pass — this section covers what
was found and fixed.

**Bug: every admin panel delete action silently failed with zero feedback.**
`deleteOperator`/`deleteLine`/`deleteStation`/`deleteNearbyPlace` (`admin/
app/(admin)/*/actions.ts`) all had the same shape: check `if (!error)` before
doing the audit-log write, then unconditionally `revalidatePath` regardless
of whether the delete actually succeeded. For operators/lines/stations,
Postgres correctly refuses the delete via `on delete restrict` foreign keys
whenever real dependent rows exist (`trips.line_id`, `stop_times.station_id`,
`lines.operator_id`) — exactly the case for any operator/line/station that's
actually in use, which is why this looked completely broken to a real user
("tidak bisa hapus operator"). Fixed all four to return a typed error state
(distinguishing Postgres `23503` foreign-key violations with a specific,
actionable message from other failures), and converted each list page's
inline `<form action={delete...}>` into a small client component using
`useActionState` so the error actually renders (`operators/delete-button.tsx`,
`lines/delete-button.tsx`, `stations/delete-button.tsx`, `nearby-places/
delete-button.tsx`). `updateOperator`/similar update actions were already
structured correctly (typed error state, `useActionState` in the edit forms)
— only delete had this gap.

**Hosted Supabase's schedule data was badly broken**: found via a direct
row-count check (`stations` 87, `lines` 6, `trips` 6823, but **`stop_times`
only 3**) — a real trip needs dozens of stop_times rows each, so this was
nowhere close to usable for real search. The shape (many trips, almost no
stop_times) points at a previous GTFS import attempt that inserted trips
successfully via the `import_gtfs_trips` RPC, then got cut off before or
during the much larger stop_times bulk-insert phase — consistent with
Cloudflare Workers' CPU-time limit if that import was ever attempted through
the deployed admin panel (a bulk import processing tens of thousands of rows
across many chunked network round-trips is a poor fit for a single Workers
request). Confirmed `admin/lib/gtfs/importer.ts`'s import is genuinely
idempotent (deletes-then-upserts stop_times scoped to exactly the
re-imported trip ids) — safe to just re-run.

**Re-running it hit the "Connection closed" investigation below**, so it
was run via a new standalone script instead:
`admin/scripts/import-real-gtfs.mts` (run via `npx tsx`) — reimplements
`importGtfsFeed`'s exact algorithm using the same `lib/gtfs/parser.ts`/
`calendar.ts` helpers (which have no `server-only` guard, unlike
`importer.ts` itself, so they can be imported outside Next.js). Matches
the existing pattern of `admin/scripts/refresh-vehicle-positions.mjs` — a
one-off/ops script that talks to Supabase directly via the service-role
key from `.env.local`, deliberately outside the Next.js request/response
cycle. **Result, verified for real**: 86 real stations, 5 real lines, 984
trip patterns → 6822 dated instances over a 7-day window → **114,085 real
stop_time rows**, confirmed via both a raw row-count check and a real
`get_station_departures`/`search_one_transfer_trips` RPC call returning
correct, real KRL data (a genuine Bogor→Sudirman itinerary transferring at
Manggarai from the Bogor line to the Cikarang line, with sensible
sequential times).

**A genuinely deep, separate bug found while trying to log into the local
admin dev server to run that import through the UI first**: every Supabase
Auth call made from within this project's Next.js server (login, and by
extension every server action using `lib/supabase/server.ts`/`middleware.ts`)
throws a generic `Error: Connection closed.` — reproduced consistently on
this machine. Methodically isolated the cause across several hypotheses,
each ruled out in turn:
- Not the `global: { fetch }` override added earlier for Cloudflare —
  reproduced identically with it fully removed.
- Not Node's fetch needing to be bound to `globalThis` — reproduced
  identically with `globalThis.fetch.bind(globalThis)` too.
- Not a stale long-running dev server — reproduced on a freshly-started one.
- Not Supabase Auth rate-limiting or bad credentials — the exact same
  `signInWithPassword` call against the real REST endpoint via plain `curl`
  succeeds instantly (200, real token).
- Not Turbopack/dev-mode specifically — reproduced identically in a real
  `next build && next start` production server too.
- Not `@supabase/ssr`/Node/this machine in general — **the exact same
  client construction and `signInWithPassword` call, run via plain `node`
  outside Next.js entirely, succeeds in 390ms.**

That last result is the important one: **this is isolated to Next.js's own
local HTTP server runtime on this machine** (dev or production build, both
equally affected) — not the application code, not Supabase, and (per the
user's own earlier successful browser login, screenshotted) not the
deployed Cloudflare Workers version either. Root cause not fully identified
(candidates include Next.js's own fetch-patching for its Data Cache
interacting badly with a Windows-specific undici/socket-reuse quirk — see
`nodejs/undici#3492` for a similar class of bug — but not confirmed).
**Practical takeaway**: don't trust curl-replay testing against this
project's local `next dev`/`next start` server on this machine for Supabase
Auth flows going forward — it's a known-broken measurement here specifically,
not a signal about the code. The standalone-script pattern above (bypass
Next.js's server entirely for anything that must actually run reliably) is
the correct workaround, not further debugging of this specific quirk.

**`TRANSIT_PROVIDER` switched from `gtfs` to `local_supabase`** (root
`.env`), at the user's explicit choice after this was diagnosed as the
reason admin panel edits never appeared in the app: `gtfs` reads
exclusively from a bundled local file baked into the app at build time,
completely disconnected from the Supabase database the admin panel
manages — not a bug, just an architecture the user hadn't been told about
before. Real, immediate consequence of the switch: `HomePage`'s nearest-
station card, `NearbyStationsPage`, the onboarding station picker, and the
`LiveMapPage` schematic diagram all share the same `stationListProvider` →
`stationProvider` provider chain, so all of them now source from the real,
live database instead of a small hardcoded subset — this is expected to
fix the "onboarding picker missing stations"/"peta doesn't match the real
map" complaints too, not just the demo-data-everywhere one. **Build-
verified only** (`flutter build apk --debug --dart-define-from-file=.env`
succeeded) — the emulator crashed again before an on-device visual
confirmation could happen; still needs a real walkthrough once a stable
device is available.

**First pass at a real user login/account system** (`lib/features/
account/`), at the user's explicit request, reversing nothing about the
existing local-only/no-account design — it's purely additive. `public.
users`/`user_preferences` were already fully provisioned in the schema
(including an `on_auth_user_created` trigger auto-creating both rows on
signup) but had never been connected to anything in the Flutter app — this
was genuinely just a Flutter-side wiring gap, not missing backend work.
`AccountController` (Riverpod `Notifier` wrapping `Supabase.instance.client
.auth`'s session stream) + `LoginPage` (email/password sign in/sign up,
matching the admin panel's own auth approach) + a new "Masuk atau buat
akun" entry point on `ProfilePage`'s existing account card (shown only
when `AppEnvironment.supabaseEnabled`; replaced by the signed-in email +
a "Keluar" button once authenticated). **Scope of this first pass
deliberately stops at working sign-up/sign-in/sign-out and session
persistence** — syncing preferences/favorites to the account is real,
already-provisioned backend capability (`user_preferences`, `user_
favorites`, `saved_routes` tables) but is follow-up work, not built yet.
`flutter analyze` clean.

**Admin panel Cloudflare redeploy hit, then worked around, a genuine local
machine limitation** (not code, not the app): rebuilding after the
delete-button fixes hit `EPERM: operation not permitted, symlink` from
OpenNext's build step, reproducibly (cleared `.open-next` and retried —
identical failure). Confirmed via the registry (`HKLM\SOFTWARE\Microsoft\
Windows\CurrentVersion\AppModelUnlock`) that Windows Developer Mode is not
enabled on this machine — required for a non-Administrator process to
create real symlinks on Windows.

**Fixed properly rather than requiring the user to change an OS-wide
setting**: traced the exact failing call in `@opennextjs/aws`'s
`copyTracedFiles.js` — it only creates a symlink when the traced source
file is *itself* already a symlink (a Next.js standalone-output artifact
pointing back into `node_modules`, always a package directory in practice).
Windows *directory junctions* are a distinct NTFS feature from symlinks and
don't require Developer Mode or elevation at all. Patched the call to
`statSync` the resolved target and pass `'junction'` when it's a directory
(falls back to the original default otherwise, and junctions are a no-op
flag on non-Windows platforms — safe everywhere). Persisted via
`patch-package` (`admin/patches/@opennextjs+aws+4.1.0.patch` +
`"postinstall": "patch-package"` in `package.json`, so this survives a
fresh `npm install`, not just a one-off hand-edit to `node_modules`).

**Verified end-to-end**: build succeeded cleanly with the patch in place,
`npx opennextjs-cloudflare deploy` succeeded, and `https://www.
temankereta.web.id/operators` correctly redirects unauthenticated
requests to `/login` (200) — the delete-button fixes, the GTFS-import-
adjacent code, and everything else from this round are now genuinely live,
not just build-verified locally.

**Demo data fully cleaned from hosted, once the app started reading it
live.** Once `TRANSIT_PROVIDER=local_supabase` was active, every demo/seed
row (the "[DATA DEMO] Operator Transit Lokal" operator, its one demo line
and one demo trip, 3 demo stations, a demo nearby-place, and a demo service
alert — all with the `10000000-0000-4000-8000-...` id prefix from the
original seed data) would have shown up in the real app right alongside
genuine KAI Commuter data. Deleted all of it directly via the REST API in
FK-safe order (trips → line → stations → operator, plus the standalone
service alert), verified via a full-table sweep for that id prefix
afterward (empty everywhere) and confirmed real data counts were
unaffected (86 stations, 6822 trips, 114085 stop_times, unchanged).

**Delete error messages on `operators`/`lines`/`stations` now say exactly
what's blocking, not just that something is.** The FK-violation messages
added earlier this round were correct but vague ("masih memiliki jalur
terkait" with no count or names) — a real user complaint after trying to
delete a demo station and getting no way to tell which schedule data was
in the way. Rewrote all three delete actions to query the blocking
count (and, for operators, the first few names) *before* attempting the
delete, so the error reads like "Jalur ini masih memiliki 6822 trip/jadwal
terkait" instead of a generic sentence. The Postgres `23503` catch block
still exists as a fallback for anything the pre-check doesn't cover.

**`app_config` finally has a real read path** (`lib/features/app_config/`)
— this table existed since Round 8 with an explicit comment admitting
"the Flutter app does not read this table yet," and the admin Settings
page has carried a visible warning saying the same thing ever since.
`AppConfigController` (Riverpod `Notifier`, real-time via a Supabase
`postgres_changes` subscription on the table) reads the `maintenance_mode`
key; `app.dart`'s `MaterialApp.router` `builder` now swaps in a real
full-screen `_MaintenanceScreen` when it's true — an actual admin-
controlled kill switch, not a Settings field with no effect. Required a
new migration, `20260806110000_app_config_public_read.sql` (grants
`anon`/`authenticated` `select`, matching the existing "Public can read
stations/lines/trips" policy shape — the table was `service_role`-only
before, which the mobile app's anon key can't touch). Applied to the local
stack; **still needs the user's manual apply to hosted**, same as every
other migration this session — I don't have a direct Postgres connection
to hosted, only the REST API (which can't run DDL). `remote_config` (the
other `app_config` key) is deliberately not wired to anything yet — no
current feature reads it, so there's nothing to gate.

## Same round, continued: GTFS import Workers limit, always-on vehicle positions, Home/Peta honesty fixes

Follow-up user feedback after the above: "why still run in local... make a
realtime data also the GTFS import isnt can be Apied from the admin panel"
and, separately, "also this peta isnt update."

**GTFS import via the deployed admin panel UI genuinely cannot handle the
real feed's full size** — this isn't a bug to fix in the importer itself,
it's a Cloudflare Workers request-handler limit (CPU time/memory for a
single request), the same root cause already identified above for why
hosted `stop_times` was truncated. `admin/app/(admin)/gtfs-import/
import-form.tsx` now defaults `window_days` to 1 (was 7) and shows an
explicit amber warning: even 1 day of the real ~86-station/~984-trip feed
is ~16k schedule rows, more than that risks the same mid-import failure
("the page will ask for a reload"). The warning tells the operator to use
`npm run import-gtfs -- <zip> <operator-id> <days>` (the standalone script
from the section above, added to `package.json` scripts) for anything
larger — that script bypasses the Workers request cycle entirely and is
what actually populated the real 114,085-row hosted dataset. The web-UI
import path stays useful for small/incremental imports; it was never going
to be the right tool for a full reimport, and now says so instead of
silently failing.

**Vehicle positions were "realtime" in name only** — `refresh_estimated_
vehicle_positions()`/`refresh_crowd_vehicle_positions()` (Round 15/19) only
ever ran when a developer manually executed `admin/scripts/
refresh-vehicle-positions.mjs` on their own machine. Nothing kept that
script running in production, so a real user's `vehiclePositionsProvider`
subscription had genuinely stale/empty data whenever nobody happened to be
running the poller — exactly the "GPS realtime tidak bergerak" complaint.
Fixed with `pg_cron` (a standard Supabase/Postgres extension, not a new
external dependency): new migration `20260806120000_vehicle_positions_
cron.sql` schedules both refresh functions every minute directly inside
Postgres. `pg_cron`'s coarsest granularity is whole minutes (vs. the Node
poller's 20s), but that's still consistent with this data's own honesty
labeling (`estimated`/`near_real_time`, never claimed `real_time`), so nothing
is oversold by the change. Applied to the local stack; **needs the user's
manual hosted apply**, same as every migration this session — no direct
Postgres/DDL access to hosted from here, REST API only.

**Home page's connection-status text was hardcoded regardless of actual
config** — `home_page.dart` always showed the literal string "Semua
berjalan lokal di perangkat" even after the switch to `local_supabase`,
the exact same class of bug flagged repeatedly earlier in this project
(demo banners, privacy-page copy, a "local-only guard" label). Replaced
with `_connectionLabel()`, switched on `AppEnvironment.provider` — now
genuinely says "Terhubung ke database secara real-time" for
`local_supabase`/`official_api`, the GTFS-file caveat for `gtfs`, and the
demo caveat only for `mock`.

**Peta (`LiveMapPage`) was almost entirely hardcoded, independent of which
provider was active**: a fixed 9-station allowlist for the station list
below the diagram, an unconditionally-shown `DemoDataBanner`, and a
`_RailDiagramPainter` with a `const` list of 8 fake station names (`Bogor`,
`Citayam`, ... `Jakarta Kota`) plus a hardcoded "Sudirman" branch label and
a `Semantics` accessibility label that explicitly said "demo" — all
regardless of whether the app was reading real hosted data. Fixed in
`lib/features/live_map/presentation/live_map_page.dart`:
- Station list below the diagram now renders every real station from
  `stationListProvider`, sorted alphabetically, not a hardcoded subset.
- `DemoDataBanner` only shows when `AppEnvironment.provider ==
  TransitProviderKind.mock`.
- `_RailDiagramPainter` takes `stationLabels`/`branchLabel` as real
  parameters instead of hardcoded constants — the main line draws the
  first 8 real stations (alphabetical), the branch draws a station with
  code `SUD` if one exists in the data, else falls back to the 9th
  station. The `Semantics` label is honest about what this is: for `mock`
  it still says "demo"; for every real provider it now says the diagram is
  an **illustrative schematic using real station names, not the actual
  line topology/order** — deliberately not claiming this is a correct route
  diagram, since building a genuine per-line-ordered diagram would need
  real line-membership data (`Station.lineIds`) that neither
  `SupabaseTransitProvider` nor `GtfsStaticScheduleProvider` currently
  populates (`lineIds` is always empty on both — checked via grep, not
  assumed). That's a real, separate gap, not something this fix pretends
  to solve.
- Added an empty-station-list guard (`AppEmptyState` instead of a crash)
  since the diagram code now indexes into real data instead of a
  guaranteed-non-empty hardcoded constant.

Verified with `flutter analyze` (whole project: 12 pre-existing `info`-level
lints, none new, none in this file) and `flutter test` (76 tests, all pass).
Admin panel rebuilt and redeployed to Cloudflare (`npm run deploy`);
confirmed live via `curl` (`www.temankereta.web.id` responds). Flutter
release APK rebuilt against the real `.env` (`TRANSIT_PROVIDER=
local_supabase`) for the user to install directly on their device.

**Still open, called out honestly rather than silently left**: a real
per-line-ordered rail diagram (needs `Station.lineIds` or equivalent
populated from `trips`/`stop_times` — not built this round); syncing
account preferences/favorites now that login exists (flagged above,
unchanged); `remote_config` still unread by the app (unchanged).

## "Stuck at the logo" on a real release install — two real causes, one found before it mattered and one that actually explains the report

User reported the release APK from the round above hung on the splash/app
icon after install — reported it again, unprompted, even after the first
fix below was built and (it turned out) never actually reached their
device. Both causes below are real; only the second one is what the user
actually hit.

**Cause #1 (real, but not the one the user hit): `main.dart` was doing a
large, pointless synchronous import before `runApp()`.**
`_importBundledGtfsFeedIfNeeded()` was `await`ed **before** `runApp()`, and
it unconditionally ran whenever `GTFS_STATIC_ENABLED=true` in `.env` —
regardless of which `TRANSIT_PROVIDER` was actually active. Since Round 9
that flag has stayed `true` while `TRANSIT_PROVIDER` moved to
`local_supabase` this round, this import (potentially tens of thousands of
Drift/SQLite row inserts for the bundled real KRL feed) was running fully
synchronously on every fresh install for **zero benefit** —
`GtfsStaticScheduleProvider`, the only consumer of this local data, is
never read when the active provider is `local_supabase`. Fixed by gating
the import on `AppEnvironment.provider == TransitProviderKind.gtfs` in
addition to the existing flag check (`lib/main.dart`) — a real, worthwhile
fix on its own merits, kept in place. But it turned out to be diagnosing a
bug that couldn't have been the one the user reported, per cause #2 below —
this exact code path only ever runs when `TRANSIT_PROVIDER` reads as
`local_supabase`/`gtfs` from real dart-defines, which the affected builds
never received in the first place.

**Cause #2 (the real one): every `flutter build apk --release` this round
was missing `--dart-define-from-file=.env`.** Rebuilding after cause #1's
fix, then again after the premium-subscription feature, both used plain
`flutter build apk --release` — dropping the flag this project has always
needed (see "Local dev environment notes" below and every prior round's
build commands). Without it, every `AppEnvironment` field falls back to its
compiled-in default: `APP_ENV` defaults to `'local'`. `AppEnvironment.
validateLocalOnly()` — a deliberate safety guard from early in this
project, whose entire job is to make a local-config build refuse to run as
a release build — throws `StateError('Build release dinonaktifkan saat
APP_ENV=local...')` as an **uncaught exception at the very first line of
`main()`**, before `runApp()` is ever reached. On Android this is
indistinguishable from a hang: the launcher's splash (the app icon) stays
on screen forever, because the native splash is only ever replaced by
Flutter's first composited frame — which never happens. This is a real,
reproducible crash, not a slow bundled import — cause #1 wouldn't have
mattered either way once the app was crashing before it could ever run.

**Caught it by actually installing the built APK and reading logcat**,
rather than continuing to reason about `main.dart` from memory — the
`Unhandled Exception: Bad state: Build release dinonaktifkan...` at
`app_environment.dart:117` → `main.dart:16` was unambiguous the moment logs
were checked. **General lesson**: when a fix looks right on paper but the
user says the bug is still there, verify the actual artifact rather than
re-reasoning about the code that produced it — a wrong build flag doesn't
show up by rereading `main.dart` no matter how carefully.

Fixed by rebuilding with the flag restored: `flutter build apk --release
--dart-define-from-file=.env`. Verified this time by installing on the
emulator and reading logcat directly (no more `Unhandled Exception`,
`FlutterGeolocator`/engine init proceeds normally) rather than trusting the
build succeeding as proof the app works.

**Also found and fixed while rebuilding**: hit a self-inflicted Gradle
failure (`package dev.fluttercommunity.plus.device_info does not exist`)
from running `flutter pub get` in the same directory *while* a backgrounded
`flutter build apk --release` was still in progress — two concurrent
Flutter-toolchain processes racing on `.dart_tool/`/`GeneratedPluginRegistrant.
java` corrupted the plugin registration. Fixed by `flutter clean` + a single
sequential `pub get` + rebuild, not by touching any dependency. **Lesson**:
never run a second `flutter`/`pub` command in the same project directory
while a `flutter build`/`flutter run` is still in flight in the background,
even in a different tool call — treat the whole Flutter toolchain as
single-threaded per project checkout.

**Delivery gap worth naming plainly**: this environment has no direct
channel to the user's physical device (no USB debugging connection to it —
only an emulator is attached) and no cloud/file-sharing tool connected
either. Every `flutter build apk` this round produced a real, correct file
on the dev machine, but *getting it onto the user's phone* was never
verified as having happened before the "still stuck" report — worth
confirming a build actually reached the test device before treating a
report as "the same bug persisting" vs. "the fix was never installed."

## Premium subscription (notify/reminder station), 14-day trial, device-based anti-abuse

User's request, verbatim: gate the "reminder N stasiun sebelum tujuan"
notification behind a paid tier, give every new account a 14-day free
trial, and stop a user from getting a second free trial by switching
accounts on the same device. Scoped via explicit clarifying questions
before writing any code (payment approach, exact feature scope, and an
honest limit on what device-based anti-abuse can actually guarantee) —
confirmed: the user's own GoPay/Midtrans merchant gateway (self-hosted,
not Play Billing — this app is direct-APK-distributed only, so Play's
digital-content billing policy doesn't apply), gating *only* the stop-alert
reminder (not transfer/missed-destination alerts, and not any other
feature), Rp 15.000/30 days, and best-effort (not foolproof) device
tracking via Android ID.

**The payment gateway's actual API contract was discovered by safe,
read-only probing, not guessed or invented** — the user only handed over a
base URL + API key and said "that API for create and check payment
status," no documentation. Mapped for real via curl: auth is an `X-API-Key`
header (not Bearer); `GET /transactions` lists settled payments (`amount`,
`status`, `time`, `issuer`, `order_id`, `transaction_id`); `GET
/create-qris?amount=N` creates a QRIS payment (returns `qris_id`, `trx_id`,
`qris_url` — a ready-made hosted checkout page — `qris_code` the raw EMV
QRIS string, and a **5-minute** expiry); `GET /api/qr-status/:qris_id`
checks status by id (`{success, paid, status}`); `GET /api/logs`/`GET
/token-status` are internal diagnostics revealing this gateway auto-manages
a GoPay merchant *session* (not a stable partner API key alone) — worth
knowing operationally, since a session can need re-auth independent of any
code here. **Explicit user permission was asked before generating even a
harmless Rp 100 test QRIS**, since unlike every other probe this one writes
a real (if trivial/unpaid) entry into the user's live merchant dashboard.

**Schema** (`supabase/migrations/20260806140000_premium_subscriptions.sql`):
- `public.subscriptions` — one row per user (`status`: `trialing`/`active`/
  `expired`/`none`, `trial_ends_at`, `current_period_end`). RLS: a user
  reads only their own row; all writes are `claim_trial()`/service_role
  only, never the client directly. Added to the `supabase_realtime`
  publication (`replica identity full`, matching the convention already set
  for every other Realtime-consumed table) so the app reflects a completed
  payment live, same UX as `app_config`'s maintenance-mode toggle.
- `public.device_trial_claims` — `device_id` (Android ID) → the first
  `user_id` that claimed a trial on it, ever. No client-readable policy —
  only `claim_trial()`'s `SECURITY DEFINER` body and service_role touch it.
  **Explicitly documented as best-effort**: `ANDROID_ID` resets on a factory
  reset and a different physical device sidesteps this entirely — this
  raises the bar on casual abuse, it does not make repeat trials
  impossible, matching what was told to the user before building it.
- `public.premium_payments` — one row per QRIS attempt (`qris_id`, `amount`
  including a small random offset — see below, `status`, `expires_at`).
  RLS: read-only, own rows.
- `claim_trial(p_device_id text)` — `SECURITY DEFINER`, idempotent per
  user (a second call just returns the existing row, never grants a second
  trial). Grants 14 days if the device is new; inserts a `status='none'`
  row (no trial) if the device already claimed one under a different
  account.
- Seeded `app_config.remote_config` with `premium_price_idr`/
  `premium_period_days`/`premium_trial_days` — closes the "remote_config
  seeded but never used" gap noted since `app_config` was first built;
  `AppConfigController` now reads these too, so price/period are admin-
  editable from the panel's Settings page without an app update.
- Verified against the local stack via `supabase db push --local`, which
  surfaced an unrelated pre-existing local-DB drift issue (an old
  `search_one_transfer_trips` signature blocking further migrations) — fixed
  with a full `supabase db reset --local` (safe; local dev data only), which
  then applied cleanly through this new migration too. **Needs the user's
  manual hosted apply**, same as every migration this session (no direct
  Postgres/DDL access to hosted from here, REST only).

**Payment integration** (`supabase/functions/premium-create-payment`,
`premium-check-payment` — Deno Edge Functions, **not deployed from this
environment**: no `SUPABASE_ACCESS_TOKEN`/CLI login available here, so the
user must run `supabase functions deploy premium-create-payment
premium-check-payment` and `supabase secrets set GOPAY_API_URL=...
GOPAY_API_KEY=...` themselves — the API key never appears in the Flutter
app, only as an Edge Function secret):
- `premium-create-payment`: verifies the caller's JWT, reads the price from
  `app_config`, adds a small random Rp 1-99 offset to the nominal amount
  (the gateway matches incoming payments by amount within a time window, so
  two riders paying the exact listed price in the same ~5-minute window
  could otherwise collide), calls the gateway, records a `premium_payments`
  row, returns the QR info to the client.
- `premium-check-payment`: verifies the caller owns the given `payment_id`,
  polls the gateway by `qris_id` (not by amount — sidesteps the collision
  risk above), and on a real payment extends/activates `subscriptions`
  (`current_period_end` extends from the *later* of now or the existing
  period end, so an early renewal doesn't lose paid-for time).

**Flutter**: `lib/core/platform/device_identity.dart` (Android ID via
`device_info_plus` — pubspec resolution needed `^13.2.0` specifically, same
`win32`-version collision pattern as `file_picker`/`geolocator` in Round
7.6 — pub's own suggested fix worked directly this time); `lib/features/
premium/domain/subscription_entitlement.dart` (pure, unit-tested — 6 new
tests in `test/features/subscription_entitlement_test.dart` — entitlement
math; an "unmetered" constant makes the whole feature a no-op gate when
`SUPABASE_ENABLED=false`, matching every other account-dependent feature's
posture in this codebase); `SubscriptionController` (Realtime + auth-state-
aware, mirrors `AppConfigController`'s shape); `PremiumPaywallPage`
(shows price from `app_config`, creates a payment, opens the gateway's own
ready-made checkout page via `url_launcher` instead of building a custom QR
renderer, polls `premium-check-payment` every 6s while open). `AccountController.
signUp()`/`signIn()` both call `claim_trial()` (idempotent, safe to call
from both — covers Supabase projects that require email confirmation,
where `signUp()` alone doesn't yet have a session to claim with).
`ActiveTripController._hasPremiumReminderEntitlement()` gates only the
stop-alert branch — transfer and missed-destination alerts stay free, per
the user's explicit scoping. `NotificationSettingsPage` shows a lock icon +
"Lihat harga & berlangganan" upsell in place of the threshold picker when
not entitled.

**Verified**: `flutter analyze` (whole project, 13 pre-existing `info`-level
lints, none new), `flutter test` (82/82 — 76 pre-existing + 6 new
entitlement tests). **Not verified end-to-end against a real payment**:
the Edge Functions are written and reviewed but can't be deployed or
exercised from this environment (no hosted Supabase CLI auth, and firing a
real payment would need actually scanning a real QR) — the user's first
real subscription purchase attempt is the first true end-to-end check of
this flow.

**Still open**: real payment end-to-end verification (blocked as above);
whatever happens if the GoPay gateway's underlying merchant session
expires mid-operation (`/token-status` exists precisely because this can
happen — no automatic alerting on it exists yet, would need the admin to
notice via that endpoint or a failed payment report); a renewal/cancel UI
(current scope is "buy more time," there's no way to view payment history
or cancel from the app yet — not requested, not built).

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

**A second, more important bug found right after that "verified" note was
first written**: that first `flutter build apk --release` was run *without*
`--dart-define-from-file=.env`. Since `AppEnvironment.name` (`APP_ENV`)
defaults to `'local'` when no dart-define supplies it, and
`AppEnvironment.validateLocalOnly()` has an explicit
`if (kReleaseMode) throw StateError(...)` guard for exactly this combination
(release build + `APP_ENV=local`), the resulting APK was correctly signed
but **threw an unhandled exception in `main()` before `runApp()` ever ran**
— on-device this doesn't crash visibly, it just **hangs forever on the
native splash screen** (confirmed via `adb shell am start -W` reporting
`Status: timeout` and a screenshot showing the splash indefinitely). A
correctly-signed APK that never boots is not a real release artifact
either — verifying the signature alone was not enough. Rebuilt with
`flutter build apk --release --dart-define-from-file=.env`: now boots to
the real onboarding screen (screenshot-verified) with the same correct
signature confirmed again. **Lesson**: any future "verify the release
build" pass must always include `--dart-define-from-file=.env` (or whatever
the real target environment file is) and an actual on-device boot check —
not just `apksigner verify`.

**Performance measured for the first time this round (PRD §34)**, using the
now-correctly-booting release build on this machine's x86_64 Android
emulator:
- **Cold start**: `adb shell am start -W` measured 4.4s once the one-time
  GTFS import had already run once (8-13s on the very first launch, which
  also does that one-time import — not representative of steady-state).
  Both numbers are **over the PRD's 2.5s target**, but a controlled A/B
  test (`--dart-define=SUPABASE_ENABLED=false`, otherwise identical build)
  showed almost the same delay with `Supabase.initialize()` completely
  removed from `main()` — meaning the app's own startup code is *not* the
  bottleneck. Logcat frame-timing during the same window shows
  `Davey! duration=867ms` and EGL swap-buffer stats averaging 800-1964ms
  per frame — this points to Impeller/GPU renderer warm-up specific to this
  x86_64 software/hybrid-rendered emulator, a well-documented category of
  emulator-only slowness, not application logic. **This number should not
  be trusted as a verdict on the 2.5s target** — it needs re-measuring on
  an actual physical mid-range Android device before drawing a real
  conclusion either way.
- **App size**: the "fat" universal `flutter build apk --release` output is
  ~103MB (bundles arm64-v8a + armeabi-v7a + x86_64 native libs all at
  once) — but that's never what a real user downloads. Built
  `--split-per-abi` for the real per-device numbers: **arm64-v8a 36.9MB**,
  armeabi-v7a 31.7MB, x86_64 38.6MB. Since arm64-v8a is what the large
  majority of real Android devices sold since ~2018 report, the realistic
  download size is **under the PRD's 50MB target** (Play Store's App
  Bundle delivery would only ship the one matching ABI anyway, and applies
  its own additional compression on top). The 103MB number some earlier
  documentation in this file cited is real but describes the wrong
  artifact for this comparison.
- **60 FPS / scroll jank**: not measured this round — would need
  `flutter run --profile` with the DevTools performance overlay on a real
  device, not attempted here.

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

## GTFS-Realtime: no real feed exists, and reverse-engineering one is out of scope

Round 18 also investigated this directly (per PRD §8/Tahap 5 "GTFS-Realtime
adapter") rather than leaving it as an assumption: searched for a public,
documented GTFS-Realtime feed or developer API from KAI Commuter for KRL
Jabodetabek. **None exists.** The official "C-Access" app has live train
tracking, but KAI Commuter doesn't publish a GTFS-RT endpoint, an API key
program, or any developer documentation anywhere found.

This means `GtfsRealtimeTransitProvider` (built early in the project,
consumes real GTFS-RT protobuf feeds when a URL is configured via
`GTFS_RT_VEHICLE_POSITIONS_URL`/etc.) has no real feed to point at — not a
code gap, a data-access one. **Explicitly ruled out**: reverse-engineering
or intercepting C-Access's own network traffic to extract and reuse its
private API endpoints. That was directly requested mid-session and directly
declined — unauthorized use of a third party's internal infrastructure,
likely a ToS violation, and exactly the scenario this project's own
"no scraping internal endpoints without permission" posture (see Round 15's
notes on the third-party starter kit's own README rule) has held to all
along. The only legitimate paths forward: an actual data partnership/API
request to KAI Commuter, or continuing to rely on the honest
schedule-estimated fallback (Round 15–17) with correct freshness labeling —
which is the current, real state of this app's "real-time" feature.

## Privacy page (PRD §32) — rewritten to match the app's actual current state

`PrivacyPage` (`lib/features/support/presentation/support_pages.dart`) said,
until Round 18, "Sinkronisasi cloud, Firebase, dan deployment tidak
diaktifkan" — written back when the app was genuinely local-only, and never
updated after Round 8 wired it to a real hosted Supabase project. Rewritten
to describe what's actually true today, structured to match PRD §32's
required content (data collected, reason, storage, deletion, user rights,
contact):

- **Fact-checked before writing, not assumed**: confirmed via grep that the
  Flutter app has **no end-user authentication flow at all** (no
  `supabase.auth` calls, no login/sign-up UI anywhere in `lib/`) — the
  `public.users`/`user_favorites`/`user_preferences`/`trip_sessions`/
  `device_tokens` tables in the schema exist for a future account system but
  are entirely unused by the mobile client today. Also confirmed:
  `SENTRY_DSN` is empty in the committed `.env` (crash reporting capability
  exists but isn't actually active), no analytics/ads SDK is a dependency
  anywhere in `pubspec.yaml`, and user reports save only to the local Drift
  DB (`ReportPage`'s existing "disimpan hanya di perangkat" claim was
  already accurate and didn't need changing).
- New page correctly describes: one-shot GPS for nearest-station, geofence/
  activity-recognition-based (not continuous-GPS) signals for both ride
  detection and the new Round 18 active-trip auto-advance, fully local
  notifications, GTFS schedule data bundled in the app by default (zero
  network calls) vs. anonymous read-only reference queries when
  `local_supabase` is selected, and an honest "not currently active" note
  for crash reporting rather than pretending the capability doesn't exist
  at all.
- **Deletion**: since there's no account, full deletion is genuinely just
  Android's own Settings > Apps > Teman Kereta > Clear data/Uninstall — the
  page says so plainly instead of describing a data-export/deletion request
  flow this app doesn't have.
- **Contact email is a placeholder** (`privasi@temankereta.id`) — flagged
  explicitly in the page's own source and here: must be replaced with a
  real, monitored contact before any public release. This is the one piece
  of this rewrite that needed information only the user has.

## Accessibility audit (PRD §33 — TalkBack/semantics, on-device)

Rounds 19-21 walked through the real semantics tree on a live emulator via
`uiautomator dump` (the same technique Round 7.6 established), rather than
just trusting that `Semantics`/`semanticLabel` had been added everywhere
intended. **Confirmed clean** — every clickable element had a real,
meaningful `content-desc`, not a generic "Button" or empty label — on:
Home, Jadwal (schedule search), Peta (live map — even the schematic rail
diagram itself has a full descriptive `content-desc`, not just its
container), Jelajahi (nearby places), Pusat notifikasi, and the top half of
Profil & pengaturan (theme selector, "Kurangi animasi" switch). Bottom-nav
tabs consistently include position context ("Tab 1 dari 5", etc.), not just
a bare label.

**A real, non-accessibility bug found along the way**: `ProfilePage` had a
`Card` unconditionally claiming *"Local-only guard aktif — Endpoint
non-lokal, Firebase, dan build release ditolak saat APP_ENV=local."* This
was true when first written, but has been flatly false since Round 8 —
this project's own committed `.env` has run `APP_ENV=remote` (real hosted
Supabase) since then, meaning the guard `validateLocalOnly()` describes has
been a documented no-op for that whole time, while this card kept claiming
it was "active." Fixed to branch on `AppEnvironment.isLocal`: shows the
original message when genuinely local, and an honest "Terhubung ke proyek
remote (`APP_ENV=$name`) — Local-only guard nonaktif secara sengaja" when
not. This is exactly the kind of stale-claim bug this project has caught
several times before (the Round 9 "Data Demo" banner, the Round 18 privacy
page) — worth remembering that *any* hardcoded status claim about the
app's own configuration needs to be re-checked whenever that configuration
changes, not just written once and trusted forever. Verified fixed via a
before/after screenshot on-device.

**Not completed — genuine environmental blocker, not a scope decision**:
the bottom half of Profil (ride-detection switch, home/work station
pickers) and the Active Trip page were never reached. The Android emulator
became acutely unstable partway through this pass — crashed outright once
(process disappeared entirely, `adb devices` came back empty), and after
two relaunches, its own System UI started throwing repeated "System UI
isn't responding" ANR dialogs before finally going to a black screen. This
reads as host-machine resource exhaustion after a very long session of
builds/tests/emulator work, not an app bug — logcat during the crashes
showed no exceptions from `id.temankereta.teman_kereta` itself. Whoever
picks this up next should either use a fresh emulator instance/reboot the
host, or a physical device, before continuing past this point — don't
assume the remaining screens are fine just because everything checked so
far was clean.

## `integration_test/` suite (Round 21 — first real on-device flow test)

PRD §37 asks for integration tests; until this round, this project had
none (only unit/widget tests and manual on-device screenshot verification).
Added the `integration_test` package (dev dependency) and
`integration_test/app_test.dart`: a single real end-to-end flow —
Home → Jadwal → search (default Bogor→Sudirman) → open the fastest result
→ start the trip → tap "Simulasikan stasiun berikutnya" repeatedly
(bounded at 30 taps so a real regression fails loudly instead of looping
forever) until arrival → "Selesaikan perjalanan" → trip-complete screen →
back to Home. Runs against `TemanKeretaApp` for real (the actual router,
actual page widgets), only swapping storage for in-memory fakes
(`MemoryPreferencesStore`, an in-memory Drift `AppDatabase`) — same
`TRANSIT_PROVIDER=mock` this project always defaults to without a
dart-define, so the whole flow is deterministic with no backend needed.

**Verified so far**: `flutter analyze` clean (had to drop an explicit
`List<Override>` type annotation — `Override` isn't a public type in this
Riverpod version, the same gotcha noted very early in this project's
history). Confirmed the app genuinely launches and initializes correctly
on a real device via `flutter test integration_test/app_test.dart -d
<device>` — logcat showed `Supabase init completed` and the Flutter engine
connecting normally.

**Not yet run to completion, for a concrete, evidenced reason**: partway
through this run, the emulator's own rendering degraded to **~30 seconds
per frame** (`EGL_emulation: app_time_stats: avg=30012ms`, repeating
consistently in logcat) — far past the 800-2000ms/frame degradation
already noted in the "Release signing" section's performance
investigation. At that rate a test with ~30 pump-and-settle cycles could
take the better part of an hour, so the run was stopped rather than left
to grind. This reads as the same host-resource-exhaustion pattern noted in
the accessibility-audit section above, just more severe by this point in
the session — not a flaw in the test itself, which is written and
statically verified correct. **Whoever runs this next should do it on a
freshly-booted emulator or physical device, ideally as close to the start
of a session as possible**, and treat a slow/hanging run as an environment
signal to investigate before assuming the test (or the app) is broken.

**Round 22 retry — actually completed a run, with a genuine-looking but
unconfirmed failure**: a later emulator session started out responsive, so
this round retried the same command. It ran to completion this time
(`01:05 +0 -1: Some tests failed.`) and failed at the very first assertion
after a real search: `Expected: exactly one matching candidate, Actual:
_TextWidgetFinder:<Found 0 widgets with text "Pilihan tercepat">` — i.e.
the default Bogor→Sudirman mock search appeared to return zero results.
Investigated this directly (not just noted and moved on): traced through
`TripSearchController.search()`, `MockTransitProvider.searchTrips()`, and
`RouteRanker.rank()` — nothing in the actual search logic can legitimately
return zero results for BOO→SUD, and none of this round's own changes
touch this code path at all (Round 22 was Kotlin/native-only plus a
pubspec removal). Reproduced manually on the same device right afterward
(fresh install, walked onboarding → Jadwal → tapped search) and caught the
same "still searching" state persisting for 60+ real seconds — while
logcat showed frame times climbing from ~15,000ms to **82,377ms per
frame** during that exact window (see the "Geofence reboot recovery"
section above for the full incident). Confirmed via the Dart VM service
that the isolate wasn't stuck in Dart code (paused isolate had an empty
stack — execution was in native/rendering code) and via temporary
`debugPrint` markers bracketing every `await` in `main()` that a clean
launch completes `main()` in ~5 seconds when the environment briefly
cooperates. **Conclusion, stated honestly**: this reads as the same
environment collapse as everywhere else in this section, most likely
manifesting here as `pumpAndSettle()` settling on a frame that was captured
before the search's actual result frame ever got composited — but this
was **not proven with 100% certainty**, only made highly likely by the
concrete frame-time evidence gathered in the same window. Whoever gets a
genuinely stable device next should treat this specific assertion as the
first thing to re-check, and only escalate it to "real bug" if it
reproduces when frame times are back to normal (tens of milliseconds, not
tens of thousands).

**Later the same round — conclusively proven environmental, not a bug.**
Rather than keep inferring from frame-time correlation, added a temporary
`print()` right after the `searchTrips()` call in `TripSearchController.
search()` (removed afterward) and reran. The failure reproduced — same
"0 widgets with text Pilihan tercepat" assertion — but the diagnostic line
printed **`TK_DIAG search() ok: provider=MockTransitProvider trips=3
ranked=3`** right before it. The search logic computed exactly the correct
3 mock trips, in ~18 seconds total wall time this run (not even a slow run
by this session's standards) — the state update genuinely happened; the
widget tree just hadn't reflected it by the time the test's `expect()` ran.
This closes the question definitively: **the app and its search logic are
correct**; `pumpAndSettle()` on this machine's emulator cannot be trusted to
mean "the frame reflecting the latest state has actually been composited
and is queryable" — a real, reproducible limitation of testing on this
specific degraded hardware, not of the code under test. Whoever runs this
next on a genuinely stable device should expect it to pass outright, with
no code changes needed.

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
  without the real apps." **Round 22 web research, inconclusive**:
  `gojek://` has real (if indirect) third-party evidence — Midtrans's own
  payment-integration docs reference launching Gojek via that bare scheme.
  `grab://open` has **no corroborating evidence found** — the closest
  official Grab documentation surfaced was `grabconnect2`, a distinct URL
  scheme for their GrabID/GrabPlatform SDK's own auth deep-linking, not a
  general "open the app" scheme. Left the string unchanged rather than
  guess-replacing it with `grabconnect2` (a different SDK's scheme is not
  a confirmed substitute for the app-launch use case here) — this remains
  an open item specifically for Grab, more likely wrong than Gojek's.
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
