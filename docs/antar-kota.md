# Intercity trains (Antar Kota)

An intercity mode next to KRL: the rider picks a named train (Parahyangan,
Anggrek, ...), where they board and where they get off, and is reminded
30, 15 and 10 minutes before arriving. There is **no official timetable**
behind it, so everything time-related is an estimate that corrects itself from
the train's real speed.

## What is in the app

- Beranda → "Mulai perjalanan" has a **KRL | Antar Kota** switch. Antar Kota
  shows `IntercityTripCard`: Naik dari → Turun di (only stations the first one
  can reach) → "Pilih kereta" (every train that serves both). Each train is its
  own entry, with its coach classes and an estimated duration.
- Intercity stations never appear in KRL lists. They live in their own
  catalog, `assets/intercity/intercity_v1.json` (bundled, so a ride works with
  no signal).
- The ride runs on the existing active-trip machinery (native GPS tracker,
  "Perjalanan aktif" screen, history). An intercity trip is an ordinary
  `TransitTrip` whose id starts with `ic|`; the stations it needs are merged in
  by `activeTripStationsProvider` only while such a trip is active.
- Station-count alerts ("3 stasiun lagi") are switched off for an intercity ride
  (threshold 0, also sent to native). Time-based reminders replace them.

## Map and your own train name

- **Peta tab → Antar Kota**: pick a train by name; its track (OpenStreetMap rails)
  and stops are drawn, with one line on how precise it is and a detail view:
  farthest stop from the line, how many station coordinates two sources agree on
  (yellow ring = one source or they differ), and the reminder that the stop list
  comes from Wikipedia, not KAI. A train in a ride that is running opens first.
- **Kereta lain (isi nama sendiri)**: in the Beranda card, any station can be
  picked on either side; a pair no listed train serves (or a train missing from
  the list) takes a name the rider types. The ride reuses the fastest listed
  train's track when one serves the pair, otherwise a straight line stretched by
  1.2 at 72 km/h; either way the estimate then follows the real speed.
- Station lists show the city and province (Nominatim reverse geocode, cleaned
  in `build_dataset.py`), not just the island.

## Reminders

`IntercityRideController` (mounted in `MainShell`) follows the active trip and the
GPS fixes the native tracker already delivers.

- `IntercityEtaEstimator`: remaining track distance (the fix is projected onto the
  train's own track) divided by a speed that starts as the dataset estimate and
  moves toward the speed the train actually keeps (weight up to 0.8, and 0.9 in
  the last 25 km), plus the standing time at the stops still ahead.
- `IntercityReminderPlanner`: fires 30, 15 and 10 once each, one minute early on
  purpose (a late reminder is worse than an early one). A reminder already inside
  the first estimate is skipped; if a GPS gap jumps past several, only the nearest
  is announced.
- Sound: `showIntercityEtaAlert`. 30 and 15 use the recorded clips
  (`eta_minutes_30`, `eta_minutes_15` in `android/.../res/raw`, also listed in
  `keep.xml`, which release builds need). The 10-minute clip
  (`eta_minutes_10`, from `assets/10menit.wav`) is followed by the bell
  (`alarm.mp3`). Source clips are kept in `assets/`; the copies in `res/raw` and
  `ios/Runner/Sounds` are what ships.
- "Tes suara peringatan" (Pengaturan) has an entry per reminder.

## The data

71 trains (Java 64, Sumatra 7) and 163 stations, `scripts/intercity/`:

1. `parse_ka.py`: Wikipedia "Daftar kereta api di Indonesia" tables (name, class,
   relation, stops). Community-written (Gapeka 2023–2025), so **the stop lists
   are the weakest link**; the route check below proves a list is geometrically
   consistent, not that it is complete.
2. `fetch_rail.sh`, `export_st.py`: OpenStreetMap rails and stations (ODbL).
3. `resolve_ka.py`: match names to station codes, put every train on the real
   track (shortest path through its stops, every station using all rail points
   around it), and check it. A route is `ok` only if no leg detours (> 1.6x the
   straight line), the whole route is not > 1.8x the straight distance, no rail
   is passed twice, and any `via` city is on the path. Two real source errors
   were found and fixed this way: a bullet note read as stations, and a stop
   listed out of rail order (Karawang before Cikarang on Jayakarta).
4. `verify_coords.py`: every station's OSM coordinate against Wikidata. 151 of
   163 agree within 150 m; 6 differ (Prupuk, Walikukun, Jember, Cepu, Batang
   Kuis, Muara Saling; both points lie on the track, so the OSM one is kept) and
   6 have a single source, all on the track. They are listed in
   `supabase/data/gtfs-antarkota/candidates/station_review.json`.
5. `build_dataset.py`: tier, estimated minutes (cruising speed by class, slower on
   winding legs, plus standing time) and the bundled JSON.

Two trains (`sribilah`, `putri-deli`, Medan) are still flagged `verified: false`:
the track in the map data loops oddly around Medan. The app shows a note.

## Not done

- The reminders run in Dart on the native tracker's fixes. The 30 / 15 / 10 logic is
  not in the Kotlin service, so it can pause if Android freezes the Dart side in
  deep doze. Port `IntercityRideController` to `TripProgressEngine` for that.
- Real GPS on a device was not exercised (the emulator's injected locations did
  not reach the app). The reminder logic was run on a simulated ride, the sound
  and notification on the emulator.
- The recap/history of an intercity trip is computed as if it were KRL (fare and
  distance); not adapted.
- Fares are not shown for intercity.
- Stops carry Wikipedia's notes ("arah Jakarta", "jadwal pagi") but direction is
  not modelled; the card shows the note.
- Sumatra beyond the seven listed trains, Whoosh, airport links and the
  Bandung Raya style commuter lines are not included.
