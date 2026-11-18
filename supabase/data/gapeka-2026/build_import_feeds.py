#!/usr/bin/env python3
"""Build import-ready GTFS zips from the GAPEKA 2026 Jawa feed: the two networks already in the database
(krl-jabodetabek, krl-yogyakarta) and every other non-intercity service, one zip per operator (gapeka-kci,
gapeka-kai). Also writes networks.json (CONTRACT.md C) and station_check.sql (cutover pre-check).

  python3 -I supabase/data/gapeka-2026/build_import_feeds.py [--exclude-fakultatif]

Reads (never writes) the source feeds and writes supabase/data/gapeka-2026/import/<name>/ plus a .zip of each.
Nothing here talks to Supabase. Every route of the Jawa feed is listed with its class; a route that is neither built
nor intercity (ARGO / EKSEKUTIF* / EKONOMI JARAK JAUH) stops the build, so nothing is dropped silently.

Notes 1-4 below are about krl-jabodetabek / krl-yogyakarta. The gapeka-* zips follow the same rules: station rows
from temp_gtfs / gtfs-krl-yogyakarta where the code is there, otherwise from the GAPEKA feed; empty times filled the
same way (old run-time profile when an old feed has that exact stop sequence, else distance), timepoint 0/1.

Why a separate build step instead of importing gtfs-gapeka-2026-jawa directly:
  1. The importer takes one operator per run; the Jawa feed mixes KAI and KCI and many networks the app does not
     host. Only KRL Jabodetabek and KRL Yogyakarta are in the database today (operator "KAI Commuter").
  2. The importer upserts station name/coordinates/facilities and line name/colour from the feed. The GAPEKA feed has
     no facilities (stop_desc) and no colours, so importing it as-is would wipe both. Station and line rows are
     therefore taken from the feeds that built the current data (temp_gtfs, gtfs-krl-yogyakarta); only stations
     that are new in GAPEKA 2026 come from the GAPEKA feed.
  3. Route ids must map onto the hosted line codes (BOGOR, CIKARANG, RANGKAS, TANGERANG, PRIOK, YKPL) or the importer
     creates duplicate lines. RANGKASBITUNG / TANJUNG_PRIOK are kept as in the old feed: the importer's
     ROUTE_ID_REMAP turns them into RANGKAS / PRIOK.
  4. The PDF prints no time at many stops where the train does stop (Berh/Sb): 9,706 rows, almost all KRL. The
     importer rejects empty times. They are filled here by linear interpolation on track-free straight-line distance
     between the nearest timed stops before and after, rounded to the minute, and marked timepoint=0 (approximate,
     per the GTFS spec). Printed GAPEKA times are never changed.
"""
import argparse
import csv
import io
import json
import math
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DATA = ROOT / "supabase" / "data"
GAPEKA = DATA / "gtfs-gapeka-2026-jawa"
OUT = DATA / "gapeka-2026" / "import"

NETWORKS = {
    "krl-jabodetabek": {
        "old": ROOT / "temp_gtfs",
        # GAPEKA route_id -> route_id of the feed that built the hosted lines
        "routes": {
            "GJ26_COMMUTER_LINE_BOGOR": "BOGOR",
            "GJ26_COMMUTER_LINE_CIKARANG": "CIKARANG",
            "GJ26_COMMUTER_LINE_RANGKASBITUNG": "RANGKASBITUNG",
            "GJ26_COMMUTER_LINE_TANGERANG": "TANGERANG",
            "GJ26_COMMUTER_LINE_TANJUNGPRIUK": "TANJUNG_PRIOK",
        },
    },
    "krl-yogyakarta": {
        "old": DATA / "gtfs-krl-yogyakarta",
        "routes": {"GJ26_COMMUTER_LINE_YOGYAKARTA": "YKPL"},
    },
}
SERVICE_START, SERVICE_END = "20261201", "20271231"


def read(path):
    with open(path, encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh))


def secs(t):
    if not t:
        return None
    h, m, s = (int(x) for x in t.split(":"))
    return h * 3600 + m * 60 + s


def hms(v):
    return f"{v // 3600:02d}:{v // 60 % 60:02d}:{v % 60:02d}"


def dist(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * 6371000 * math.asin(math.sqrt(h))


class Profiles:
    """Run-time proportions between two printed stops, learned from the feed that built the current data (which has a
    time at every stop). For a gap A..B with stops m1..mk in between, each old trip that calls at A, m1..mk, B in that
    order gives fractions (t_mi - t_A) / (t_B - t_A); the median per stop is used. `exclude` drops one train number
    (leave-one-out check)."""

    def __init__(self, old_dirs):
        # One feed directory, or several (samples from all of them are pooled; matching is by station code sequence).
        self.trips = []
        for old_dir in old_dirs if isinstance(old_dirs, (list, tuple)) else [old_dirs]:
            trips = {t["trip_id"]: t.get("trip_short_name", "") for t in read(old_dir / "trips.txt")}
            seq = {}
            for r in read(old_dir / "stop_times.txt"):
                seq.setdefault(r["trip_id"], []).append((int(r["stop_sequence"]), r["stop_id"], secs(r["departure_time"]), secs(r["arrival_time"])))
            for tid, rows in seq.items():
                rows.sort()
                self.trips.append((trips.get(tid, ""), [x[1] for x in rows], {x[1]: i for i, x in enumerate(rows)}, rows))
        self.cache = {}

    def fractions(self, key, exclude=None):
        ck = (key, exclude)
        if ck in self.cache:
            return self.cache[ck]
        a, mids, b = key[0], key[1:-1], key[-1]
        samples = []
        for ka, stops, idx, rows in self.trips:
            if ka == exclude or a not in idx or b not in idx:
                continue
            ia, ib = idx[a], idx[b]
            if ib - ia != len(mids) + 1 or tuple(stops[ia + 1:ib]) != mids:
                continue
            t0, t1 = rows[ia][2], rows[ib][3]
            if t1 is None or t0 is None or t1 <= t0:
                continue
            samples.append([(rows[ia + 1 + j][3] - t0) / (t1 - t0) for j in range(len(mids))])
        out = [sorted(col)[len(col) // 2] for col in zip(*samples)] if samples else None
        self.cache[ck] = out
        return out


def interpolate(rows, coord, profiles=None, exclude=None, stats=None):
    """rows: one trip's stop_times sorted by stop_sequence. Fills empty times in place; returns how many were filled.
    Uses the old run-time profile for the gap when one exists, else straight-line distance."""
    times = [(secs(r["arrival_time"]), secs(r["departure_time"])) for r in rows]
    cum = [0.0]
    for a, b in zip(rows, rows[1:]):
        cum.append(cum[-1] + dist(coord[a["stop_id"]], coord[b["stop_id"]]))
    timed = [i for i, (a, d) in enumerate(times) if a is not None and d is not None]
    if not timed or timed[0] != 0 or timed[-1] != len(rows) - 1:
        raise SystemExit(f"trip {rows[0]['trip_id']}: first/last stop has no printed time, cannot interpolate")
    filled = 0
    for lo, hi in zip(timed, timed[1:]):
        t0, t1, d0, d1 = times[lo][1], times[hi][0], cum[lo], cum[hi]
        prev = t0
        prof = profiles.fractions(tuple(r["stop_id"] for r in rows[lo:hi + 1]), exclude) if profiles and hi - lo > 1 else None
        if stats is not None and hi - lo > 1:
            stats["profile" if prof else "distance"] += hi - lo - 1
        for i in range(lo + 1, hi):
            k = prof[i - lo - 1] if prof else (cum[i] - d0) / (d1 - d0) if d1 > d0 else (i - lo) / (hi - lo)
            v = round((t0 + k * (t1 - t0)) / 60) * 60
            v = min(max(v, prev), t1)  # never earlier than the stop before, never later than the next printed time
            rows[i]["arrival_time"] = rows[i]["departure_time"] = hms(v)
            rows[i]["timepoint"] = "0"
            prev = v
            filled += 1
    for i in timed:
        rows[i]["timepoint"] = "1"
    return filled


def write(path, header, rows):
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=header, extrasaction="ignore", lineterminator="\n")
    w.writeheader()
    w.writerows(rows)
    path.write_text(buf.getvalue(), encoding="utf-8")


def build(name, cfg, include_fak):
    g_routes = {r["route_id"]: r for r in read(GAPEKA / "routes.txt")}
    g_stops = {r["stop_id"]: r for r in read(GAPEKA / "stops.txt")}
    old = cfg["old"]
    o_routes = {r["route_id"]: r for r in read(old / "routes.txt")}
    o_stops = {r["stop_id"]: r for r in read(old / "stops.txt")}
    o_agency = read(old / "agency.txt")

    missing = [v for v in cfg["routes"].values() if v not in o_routes]
    if missing:
        raise SystemExit(f"{name}: old feed has no route {missing}")
    services = {"GJ26_HARIAN"} | ({"GJ26_FAKULTATIF"} if include_fak else set())
    trips = [dict(t, route_id=cfg["routes"][t["route_id"]]) for t in read(GAPEKA / "trips.txt")
             if t["route_id"] in cfg["routes"] and t["service_id"] in services]
    skipped_fak = sum(1 for t in read(GAPEKA / "trips.txt") if t["route_id"] in cfg["routes"] and t["service_id"] == "GJ26_FAKULTATIF") if not include_fak else 0
    keep = {t["trip_id"] for t in trips}
    st = [r for r in read(GAPEKA / "stop_times.txt") if r["trip_id"] in keep]
    used = {r["stop_id"] for r in st}

    # Stations: existing rows verbatim (names, facilities in stop_desc, accessibility); only new codes from GAPEKA.
    new_codes = sorted(used - set(o_stops))
    stop_header = list(next(iter(o_stops.values())).keys())
    stops = [o_stops[c] for c in sorted(used & set(o_stops))]
    for c in new_codes:
        g = g_stops[c]
        stops.append({k: "" for k in stop_header} | {"stop_id": c, "stop_code": c, "stop_name": g["stop_name"],
                                                      "stop_lat": g["stop_lat"], "stop_lon": g["stop_lon"], "location_type": "0"})
    # Distances for interpolation. temp_gtfs carries no coordinates (empty -> the importer keeps the ones already in
    # the database), so fall back to the GAPEKA feed's coordinates, which come from the same repo sources.
    def ll(s):
        src = s if s.get("stop_lat") and s.get("stop_lon") else g_stops[s["stop_id"]]
        return float(src["stop_lat"]), float(src["stop_lon"])
    coord = {s["stop_id"]: ll(s) for s in stops}

    by_trip = {}
    for r in st:
        by_trip.setdefault(r["trip_id"], []).append(r)
    profiles = Profiles(old)
    stats = {"profile": 0, "distance": 0}
    filled = 0
    for rows in by_trip.values():
        rows.sort(key=lambda r: int(r["stop_sequence"]))
        filled += interpolate(rows, coord, profiles, stats=stats)
    st = [r for rows in by_trip.values() for r in rows]

    # Validation: nothing the importer would reject or misfile.
    for tid, rows in by_trip.items():
        vals = [(secs(r["arrival_time"]), secs(r["departure_time"])) for r in rows]
        assert all(a is not None and d is not None and a <= d for a, d in vals), tid
        assert all(vals[i][1] <= vals[i + 1][0] for i in range(len(vals) - 1)), f"time goes back in {tid}"
        assert len(rows) >= 2, tid
    assert {r["stop_id"] for r in st} <= set(coord)
    assert len({t["trip_id"] for t in trips}) == len(trips)

    d = OUT / name
    d.mkdir(parents=True, exist_ok=True)
    write(d / "agency.txt", list(o_agency[0].keys()), o_agency)
    write(d / "routes.txt", list(next(iter(o_routes.values())).keys()), [o_routes[v] for v in sorted(set(cfg["routes"].values()))])
    write(d / "stops.txt", stop_header, stops)
    write(d / "trips.txt", ["route_id", "service_id", "trip_id", "trip_headsign", "trip_short_name", "block_id"], trips)
    write(d / "stop_times.txt", ["trip_id", "arrival_time", "departure_time", "stop_id", "stop_sequence", "pickup_type", "drop_off_type", "timepoint"], st)
    cal = [{"service_id": s, **{k: "1" for k in ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")},
            "start_date": SERVICE_START, "end_date": SERVICE_END} for s in sorted(services)]
    write(d / "calendar.txt", ["service_id", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "start_date", "end_date"], cal)
    write(d / "feed_info.txt", ["feed_publisher_name", "feed_publisher_url", "feed_lang", "feed_start_date", "feed_end_date", "feed_version"],
          [{"feed_publisher_name": "Teman Kereta (dari KP DJKA 116/2026, GAPEKA Jawa)", "feed_publisher_url": "https://djka.kemenhub.go.id/",
            "feed_lang": "id", "feed_start_date": SERVICE_START, "feed_end_date": SERVICE_END, "feed_version": f"gapeka-2026-{name}"}])
    zp = OUT / f"{name}.zip"
    with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(d.glob("*.txt")):
            z.write(f, f.name)
    timed = sum(1 for r in st if r["timepoint"] == "1")
    print(f"{name}: {len(trips)} trips ({skipped_fak} fakultatif left out), {len(st)} stop_times "
          f"({timed} printed, {filled} interpolated: {stats['profile']} from old run-time profile, {stats['distance']} by distance), "
          f"{len(stops)} stations, new: {new_codes or '-'} -> {zp.relative_to(ROOT)}")
    for gid, rid in cfg["routes"].items():
        print(f"    {gid:36s} -> {rid:14s} {sum(1 for t in trips if t['route_id'] == rid)} trips")



# ---------------------------------------------------------------------------------------------------------------------
# All other non-intercity GAPEKA 2026 Jawa services (not in the database yet), one zip per operator (routes.agency_id
# is kept so the importer's --operator-map KAI=<uuid>,KCI=<uuid> can file each line under its operator).
# GAPEKA route_id -> (line code, route_short_name, route_long_name). Codes: uppercase, no GJ26_ prefix, never one of
# the hosted codes (BOGOR, CIKARANG, RANGKAS, TANGERANG, PRIOK, NAMBO, YKPL) or app aliases (RANGKASBITUNG,
# TANJUNG_PRIOK, BEKASI, SERPONG). Rule: the name without spaces; airport lines and Bandung Raya use the short form
# (BST, YIA, SMO, BDR as in CONTRACT.md). No route_color: the PDF has none and none is invented.
GROUPS = {
    "gapeka-kci": {
        "agency": "KCI",
        "routes": {
            "GJ26_COMMUTER_LINE_BST": ("BST", "Bandara Soetta", "Commuter Line Bandara Soetta"),
            "GJ26_COMMUTER_LINE_YIA": ("YIA", "Bandara YIA", "Commuter Line Bandara YIA"),
            "GJ26_COMMUTER_LINE_PRAMEKS": ("PRAMEKS", "Prameks", "Commuter Line Prameks"),
            "GJ26_COMMUTER_LINE_BANDUNG_RAYA": ("BDR", "Bandung Raya", "Commuter Line Bandung Raya"),
            "GJ26_COMMUTER_LINE_GARUT": ("GARUT", "Garut", "Commuter Line Garut"),
            "GJ26_COMMUTER_LINE_WALAHAR": ("WALAHAR", "Walahar", "Commuter Line Walahar"),
            "GJ26_COMMUTER_LINE_JATILUHUR": ("JATILUHUR", "Jatiluhur", "Commuter Line Jatiluhur"),
            "GJ26_COMMUTER_LINE_MERAK": ("MERAK", "Merak", "Commuter Line Merak"),
            "GJ26_COMMUTER_LINE_DHOHO": ("DHOHO", "Dhoho", "Commuter Line Dhoho"),
            "GJ26_COMMUTER_LINE_PENATARAN": ("PENATARAN", "Penataran", "Commuter Line Penataran"),
            "GJ26_COMMUTER_LINE_JENGGALA": ("JENGGALA", "Jenggala", "Commuter Line Jenggala"),
            "GJ26_COMMUTER_LINE_SUPAS": ("SUPAS", "Supas", "Commuter Line Supas"),
            "GJ26_COMMUTER_LINE_ARJONEGORO": ("ARJONEGORO", "Arjonegoro", "Commuter Line Arjonegoro"),
            "GJ26_COMMUTER_LINE_BLORASURA": ("BLORASURA", "Blorasura", "Commuter Line Blorasura"),
        },
    },
    "gapeka-kai": {
        "agency": "KAI",
        "routes": {
            "GJ26_BANDARA_SMO": ("SMO", "Bandara Adi Soemarmo", "KA Bandara Adi Soemarmo"),
            "GJ26_KA_FEEDER": ("FEEDER", "Feeder", "KA Feeder Padalarang - Bandung"),
            "GJ26_BATARA_KRESNA": ("BATARAKRESNA", "Batara Kresna", "KA Batara Kresna"),
            "GJ26_KEDUNG_SEPUR": ("KEDUNGSEPUR", "Kedung Sepur", "KA Kedung Sepur"),
            "GJ26_PANDANWANGI": ("PANDANWANGI", "Pandanwangi", "KA Pandanwangi"),
            "GJ26_SILIWANGI": ("SILIWANGI", "Siliwangi", "KA Siliwangi"),
        },
    },
}
HOSTED_CODES = {"BOGOR", "CIKARANG", "RANGKAS", "TANGERANG", "PRIOK", "NAMBO", "YKPL", "RANGKASBITUNG", "TANJUNG_PRIOK",
                "BEKASI", "SERPONG"}
# Intercity classes (Kelas GAPEKA), out of scope here: they go to the app's intercity asset.
INTERCITY_CLASSES = ("ARGO", "EKSEKUTIF", "EKONOMI JARAK JAUH")
OLD_STATION_FEEDS = [ROOT / "temp_gtfs", DATA / "gtfs-krl-yogyakarta"]  # first match wins

# Networks for the app (CONTRACT.md C). A network = stations a rider can travel between on this app's trains, with
# transfers. Grouped by region and checked for connectivity below. NAMBO is listed because the app knows the code
# (lib/.../line_transfer_router.dart); no feed here produces it.
NETWORK_DEF = [
    ("jabodetabek", "Jabodetabek", ["BOGOR", "CIKARANG", "RANGKAS", "TANGERANG", "PRIOK", "NAMBO", "BST", "MERAK", "WALAHAR", "JATILUHUR"]),
    ("jogja", "Yogyakarta", ["YKPL", "YIA", "PRAMEKS", "SMO", "BATARAKRESNA"]),
    ("bandung", "Bandung Raya", ["BDR", "GARUT", "FEEDER"]),
    ("jatim", "Jawa Timur", ["DHOHO", "PENATARAN", "JENGGALA", "SUPAS", "ARJONEGORO", "BLORASURA"]),
    ("semarang", "Semarang", ["KEDUNGSEPUR"]),
    ("sukabumi", "Sukabumi-Cianjur", ["SILIWANGI"]),
    ("banyuwangi", "Jember-Banyuwangi", ["PANDANWANGI"]),
]
LINE_CODE_ALIASES = {"RANGKASBITUNG": "RANGKAS", "TANJUNG_PRIOK": "PRIOK"}  # importer ROUTE_ID_REMAP


def gclass(route):
    return route["route_desc"].replace("Kelas GAPEKA: ", "")


def route_inventory():
    """Every route in the Jawa feed with its class and where it goes, so nothing is dropped silently."""
    g_routes = read(GAPEKA / "routes.txt")
    g_trips = read(GAPEKA / "trips.txt")
    where = {gid: f"{name} ({rid})" for name, cfg in NETWORKS.items() for gid, rid in cfg["routes"].items()}
    where |= {gid: f"{name} ({v[0]})" for name, cfg in GROUPS.items() for gid, v in cfg["routes"].items()}
    out = []
    for r in g_routes:
        cls = gclass(r)
        n = sum(1 for t in g_trips if t["route_id"] == r["route_id"])
        if r["route_id"] in where:
            out.append((r["route_id"], r["agency_id"], cls, n, "IN " + where[r["route_id"]]))
        elif any(k in cls for k in INTERCITY_CLASSES):
            out.append((r["route_id"], r["agency_id"], cls, n, "OUT intercity"))
        else:
            raise SystemExit(f"route {r['route_id']} ({cls}) is neither built nor intercity: add it to GROUPS or decide")
    return out


def build_group(name, cfg, include_fak):
    g_routes = {r["route_id"]: r for r in read(GAPEKA / "routes.txt")}
    g_stops = {r["stop_id"]: r for r in read(GAPEKA / "stops.txt")}
    g_agency = {r["agency_id"]: r for r in read(GAPEKA / "agency.txt")}
    rmap = cfg["routes"]
    for gid, (code, _, _) in rmap.items():
        if gid not in g_routes:
            raise SystemExit(f"{name}: {gid} not in GAPEKA routes")
        if g_routes[gid]["agency_id"] != cfg["agency"]:
            raise SystemExit(f"{name}: {gid} is agency {g_routes[gid]['agency_id']}, expected {cfg['agency']}")
        if code in HOSTED_CODES or code.startswith("GJ26") or code != code.upper():
            raise SystemExit(f"{name}: bad line code {code}")
    services = {"GJ26_HARIAN"} | ({"GJ26_FAKULTATIF"} if include_fak else set())
    all_trips = [t for t in read(GAPEKA / "trips.txt") if t["route_id"] in rmap]
    trips = [dict(t, route_id=rmap[t["route_id"]][0]) for t in all_trips if t["service_id"] in services]
    skipped_fak = len(all_trips) - len(trips)
    keep = {t["trip_id"] for t in trips}
    st = [r for r in read(GAPEKA / "stop_times.txt") if r["trip_id"] in keep]
    used = {r["stop_id"] for r in st}

    # Stations: rows of the feeds that built the current data where the code is there (keeps facilities, names and
    # DB coordinates); every other code from the GAPEKA feed (name + repo-sourced coordinates, no facilities).
    old_stops = [{r["stop_id"]: r for r in read(d / "stops.txt")} for d in OLD_STATION_FEEDS]
    stop_header = list(next(iter(old_stops[0].values())).keys())
    stops, source, name_diff = [], {}, []
    for c in sorted(used):
        hit = next(((i, o[c]) for i, o in enumerate(old_stops) if c in o), None)
        if hit:
            i, row = hit
            stops.append({k: "" for k in stop_header} | {k: v for k, v in row.items() if k in stop_header})
            source[c] = OLD_STATION_FEEDS[i].name
            if row["stop_name"] != g_stops[c]["stop_name"]:
                name_diff.append(f"{c}: kept '{row['stop_name']}' (GAPEKA feed: '{g_stops[c]['stop_name']}')")
        else:
            g = g_stops[c]
            stops.append({k: "" for k in stop_header} | {"stop_id": c, "stop_code": c, "stop_name": g["stop_name"],
                                                          "stop_lat": g["stop_lat"], "stop_lon": g["stop_lon"], "location_type": "0"})
            source[c] = "gapeka"
    new_codes = sorted(c for c, s in source.items() if s == "gapeka")

    def ll(s):
        src = s if s.get("stop_lat") and s.get("stop_lon") else g_stops[s["stop_id"]]
        return float(src["stop_lat"]), float(src["stop_lon"])
    coord = {s["stop_id"]: ll(s) for s in stops}

    by_trip = {}
    for r in st:
        by_trip.setdefault(r["trip_id"], []).append(r)
    profiles = Profiles(OLD_STATION_FEEDS)
    route_of = {t["trip_id"]: t["route_id"] for t in trips}
    per_route = {}
    for tid, rows in by_trip.items():
        rows.sort(key=lambda r: int(r["stop_sequence"]))
        s = per_route.setdefault(route_of[tid], {"profile": 0, "distance": 0, "filled": 0})
        s["filled"] += interpolate(rows, coord, profiles, stats=s)
    st = [r for rows in by_trip.values() for r in rows]

    for tid, rows in by_trip.items():
        vals = [(secs(r["arrival_time"]), secs(r["departure_time"])) for r in rows]
        assert all(a is not None and d is not None and a <= d for a, d in vals), tid
        assert all(vals[i][1] <= vals[i + 1][0] for i in range(len(vals) - 1)), f"time goes back in {tid}"
        assert len(rows) >= 2, tid
        assert all(r["timepoint"] in ("0", "1") for r in rows), tid
    assert {r["stop_id"] for r in st} <= set(coord)
    assert len(keep) == len(trips) == len(by_trip)

    d = OUT / name
    d.mkdir(parents=True, exist_ok=True)
    write(d / "agency.txt", list(g_agency[cfg["agency"]].keys()), [g_agency[cfg["agency"]]])
    route_rows = [{"route_id": code, "agency_id": g_routes[gid]["agency_id"], "route_short_name": short, "route_long_name": long_,
                   "route_desc": g_routes[gid]["route_desc"], "route_type": g_routes[gid]["route_type"], "route_color": "", "route_text_color": ""}
                  for gid, (code, short, long_) in rmap.items()]
    write(d / "routes.txt", list(route_rows[0].keys()), route_rows)
    write(d / "stops.txt", stop_header, stops)
    write(d / "trips.txt", ["route_id", "service_id", "trip_id", "trip_headsign", "trip_short_name", "block_id"], trips)
    write(d / "stop_times.txt", ["trip_id", "arrival_time", "departure_time", "stop_id", "stop_sequence", "pickup_type", "drop_off_type", "timepoint"], st)
    used_services = sorted({t["service_id"] for t in trips})
    cal = [{"service_id": s, **{k: "1" for k in ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")},
            "start_date": SERVICE_START, "end_date": SERVICE_END} for s in used_services]
    write(d / "calendar.txt", ["service_id", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "start_date", "end_date"], cal)
    write(d / "feed_info.txt", ["feed_publisher_name", "feed_publisher_url", "feed_lang", "feed_start_date", "feed_end_date", "feed_version"],
          [{"feed_publisher_name": "Teman Kereta (dari KP DJKA 116/2026, GAPEKA Jawa)", "feed_publisher_url": "https://djka.kemenhub.go.id/",
            "feed_lang": "id", "feed_start_date": SERVICE_START, "feed_end_date": SERVICE_END, "feed_version": f"gapeka-2026-{name}"}])
    zp = OUT / f"{name}.zip"
    with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(d.glob("*.txt")):
            z.write(f, f.name)

    timed = sum(1 for r in st if r["timepoint"] == "1")
    filled = sum(s["filled"] for s in per_route.values())
    print(f"{name} (agency {cfg['agency']}): {len(rmap)} routes, {len(trips)} trips ({skipped_fak} fakultatif left out), "
          f"{len(st)} stop_times ({timed} printed, {filled} interpolated), {len(stops)} stations "
          f"({len(stops) - len(new_codes)} from old feeds, {len(new_codes)} from GAPEKA) -> {zp.relative_to(ROOT)}")
    print(f"    {'GAPEKA route':34s} {'code':13s} {'trips':>5s} {'fak':>4s} {'rows':>5s} {'printed':>7s} {'interp':>6s} {'profile':>7s} {'dist':>5s} stations")
    for gid, (code, _, _) in rmap.items():
        tids = [t["trip_id"] for t in trips if t["route_id"] == code]
        rows = [r for t in tids for r in by_trip[t]]
        s = per_route.get(code, {"profile": 0, "distance": 0, "filled": 0})
        fak = sum(1 for t in trips if t["route_id"] == code and t["service_id"] == "GJ26_FAKULTATIF")
        print(f"    {gid:34s} {code:13s} {len(tids):5d} {fak:4d} {len(rows):5d} {sum(r['timepoint'] == '1' for r in rows):7d} "
              f"{s['filled']:6d} {s['profile']:7d} {s['distance']:5d} {len({r['stop_id'] for r in rows})}")
    for line in name_diff:
        print("    station name kept from old feed:", line)
    print(f"    new station codes (not in temp_gtfs or gtfs-krl-yogyakarta; may overwrite an existing DB row's name/coords/facilities):")
    print("     ", ", ".join(f"{c} {g_stops[c]['stop_name']}" for c in new_codes))
    return {c: g_stops[c] for c in new_codes}


def write_station_check(new_stops):
    """station_check.sql: read-only query for the cutover. Lists every station code the GAPEKA zips take from the GAPEKA
    feed (not in temp_gtfs / gtfs-krl-yogyakarta) that ALREADY exists in public.stations, with the name/coordinates
    the import would write and the distance between the two positions. Empty result = no existing row is overwritten."""
    vals = ",\n".join(f"  ('{c}', '{g['stop_name'].replace(chr(39), chr(39) * 2)}', {g['stop_lat']}, {g['stop_lon']})"
                       for c, g in sorted(new_stops.items()))
    sql = f"""-- GAPEKA 2026: station rows the gapeka-kci / gapeka-kai import would overwrite. READ-ONLY. Generated by
-- build_import_feeds.py; do not edit by hand. Run in the Supabase SQL editor BEFORE importing those zips.
-- The importer upserts stations on code: name, latitude/longitude and facilities (= {{}} here, the GAPEKA feed has no
-- stop_desc) and wheelchair_accessible (= null) are replaced for every code below that already exists.
-- {len(new_stops)} codes. Empty result = nothing existing is touched.
with feed(code, name, lat, lon) as (values
{vals}
)
select s.code, s.name as db_name, f.name as feed_name, s.latitude as db_lat, s.longitude as db_lon, f.lat as feed_lat,
       f.lon as feed_lon,
       round((2 * 6371000 * asin(sqrt(power(sin(radians(f.lat - s.latitude) / 2), 2)
             + cos(radians(s.latitude)) * cos(radians(f.lat)) * power(sin(radians(f.lon - s.longitude) / 2), 2))))::numeric) as moved_m,
       s.facilities <> '{{}}'::jsonb as db_has_facilities, s.wheelchair_accessible as db_wheelchair, s.is_active
from feed f
join public.stations s on s.code = f.code
order by s.code;
"""
    (OUT.parent / "station_check.sql").write_text(sql, encoding="utf-8")
    print(f"station_check.sql: {len(new_stops)} station codes taken from the GAPEKA feed")


def built_line_stations():
    """line code -> set of station codes, read back from every built feed folder in import/."""
    lines = {}
    for d in sorted(p for p in OUT.iterdir() if p.is_dir()):
        t2r = {t["trip_id"]: LINE_CODE_ALIASES.get(t["route_id"], t["route_id"]) for t in read(d / "trips.txt")}
        for r in read(d / "stop_times.txt"):
            lines.setdefault(t2r[r["trip_id"]], set()).add(r["stop_id"])
    return lines


def write_networks():
    lines = built_line_stations()
    listed = [c for _, _, ls in NETWORK_DEF for c in ls]
    dup = sorted({c for c in listed if listed.count(c) > 1})
    if dup:
        raise SystemExit(f"line in more than one network: {dup}")
    missing = sorted(set(lines) - set(listed))
    if missing:
        raise SystemExit(f"built lines not in any network: {missing}")
    net_of = {c: nid for nid, _, ls in NETWORK_DEF for c in ls}
    print("networks.json:")
    for nid, label, ls in NETWORK_DEF:
        present = [c for c in ls if c in lines]
        # connectivity: lines joined when they share a station
        comp = {c: c for c in present}
        def f(x):
            while comp[x] != x:
                x = comp[x]
            return x
        for i, a in enumerate(present):
            for b in present[i + 1:]:
                if lines[a] & lines[b]:
                    comp[f(a)] = f(b)
        parts = len({f(c) for c in present})
        stations = set().union(*(lines[c] for c in present)) if present else set()
        absent = [c for c in ls if c not in lines]
        print(f"    {nid:12s} {label:20s} {len(present)} lines, {len(stations)} stations, "
              f"{'connected' if parts == 1 else f'{parts} separate parts'}"
              f"{'; not in any feed here: ' + ', '.join(absent) if absent else ''}: {', '.join(ls)}")
        if parts > 1:
            raise SystemExit(f"network {nid} is not connected")
    st_nets = {}
    for code, sts in lines.items():
        for s in sts:
            st_nets.setdefault(s, {}).setdefault(net_of[code], []).append(code)
    cross = {s: v for s, v in st_nets.items() if len(v) > 1}
    print("    cross-network stations:", "; ".join(f"{s} " + " / ".join(f"{n}: {','.join(sorted(c))}" for n, c in sorted(v.items()))
                                              for s, v in sorted(cross.items())) or "-")
    doc = {"networks": [{"id": nid, "label": label, "lines": ls} for nid, label, ls in NETWORK_DEF]}
    (OUT.parent / "networks.json").write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return cross

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    # Fakultatif trains (Lampiran IV) are included by default (decided 2026-11-18); they keep service_id
    # GJ26_FAKULTATIF so the app can label them.
    ap.add_argument("--exclude-fakultatif", action="store_true", help="leave out trips marked FAKULTATIF in Lampiran IV")
    a = ap.parse_args()
    print("Routes in the GAPEKA 2026 Jawa feed:")
    for rid, agency, cls, n, where in route_inventory():
        print(f"    {rid:36s} {agency:3s} {cls:52s} {n:4d} trips  {where}")
    for name, cfg in NETWORKS.items():
        build(name, cfg, not a.exclude_fakultatif)
    new_stops = {}
    for name, cfg in GROUPS.items():
        new_stops |= build_group(name, cfg, not a.exclude_fakultatif)
    write_station_check(new_stops)
    write_networks()
