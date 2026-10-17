# KRL Yogyakarta–Palur

A second rail network next to Jabodetabek. The two are not connected: every
station can be picked on either side of the route form, but a pair across the
networks (say Bekasi → Palur) has no trip.

## Data

- Source: KAI Commuter timetable PDF "Update 2 Juni 2026" (one time per
  station; 27 trips: 12 Palur→Yogyakarta, 15 Yogyakarta→Palur).
- `supabase/data/gtfs-krl-yogyakarta/` is the corrected GTFS feed (route
  `YKPL`, daily calendar, boarding allowed everywhere). It can be imported with
  the admin panel's GTFS importer, like the Jabodetabek feed.
- `supabase/migrations/20261018090000_krl_yogyakarta.sql` loads the same data
  directly: 1 line, 13 stations, `station_lines`, 189 trips (27 × 7 days) and
  2.457 `stop_times`. Additive and idempotent; it refuses to run if a station
  code is already used by a different station.
- Trips use the **same service-date window as Jabodetabek (2026-08-07..13)** on
  purpose. The app moves "today" back by whole weeks into that window
  (`weekdayAlignedShift`), and the window is taken over *all* trips, so a
  different Jogja window would shift Jabodetabek too. Re-importing Jabodetabek
  for a new window means re-importing Jogja for the same window.
- All 13 coordinates were compared with OpenStreetMap (Nominatim): the largest
  difference is 57 m.
- Track geometry: `railLineShapes['YKPL']` in `rail_line_shapes.dart`, 446
  points from OpenStreetMap `railway=rail` (ODbL), the shortest track path
  through the 13 stations in order. Stations sit 2–69 m from it.

## Network separation

`lib/domain/usecases/transit_network.dart` decides a station's network from its
lines (`YKPL` → Jogja, anything else → Jabodetabek).

- Route form: all stations selectable on both sides.
- `TripSearchController.search` refuses a mixed pair with `crossNetworkMessage`;
  `SupabaseTransitProvider.searchTrips` returns nothing for it (no estimated
  route either). The nearest-station auto-fill moves the *default* destination
  to the origin's network, and never one the rider picked.
- For a Jogja pair the provider answers from the real timetable (no estimates).
- Live map: two tabs, Jabodetabek and Yogyakarta. The selected network is framed
  and highlighted, the other network's tracks are dimmed, and the line chips
  list only the selected network's lines. With only one network in the data the
  tabs are hidden.

## Fare

Same scheme as Jabodetabek: Rp3.000 for the first 25 km, +Rp1.000 per started
10 km, measured on the track geometry. Yogyakarta → Palur is ≈ 66 km, so
Rp8.000, which matches the amount reported by Metro TV, Liputan6 and Yogya Pos.
kci.id sits behind a Cloudflare human check that automated tools cannot pass,
so the amount was not read from there.

## Open points

- The PDF gives one time per station; arrival equals departure.
- The PDF does not state which days it applies to. The feed assumes daily.
- Prameks (Yogyakarta–Kutoarjo) is in the same PDF and is not included.
