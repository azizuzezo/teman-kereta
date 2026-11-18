"""Builds assets/intercity/intercity_v2.json: the intercity catalog with the real
GAPEKA 2026 timetable (valid from 2026-12-01).

Run from the repo root, stdlib only:

    python3 -I scripts/intercity/build_dataset_v2.py

Inputs (all in the repo):
  assets/intercity/intercity_v1.json         stations (verified coordinates), v1 trains, OSM track paths
  supabase/data/gtfs-gapeka-2026-jawa/       GTFS from KP DJKA 116/2026 (GAPEKA Jawa)
  supabase/data/gtfs-gapeka-2026-sumbagsel/  GTFS from KP DJKA 119/2026 (GAPEKA Sumbagsel)

What goes in
  * Every v1 service, unchanged (speed-based estimates). Those in a region GAPEKA 2026 covers (Jawa, Sumbagsel)
    get "until": "2026-11-30": from 2026-12-01 the GAPEKA services replace them. The two Medan trains (Sumut has no
    GAPEKA 2026 feed here) have no "until". Keeping them keeps old trip ids ("ic|cakrabuana|...") resolvable and
    keeps today's behaviour before 2026-12-01.
  * GAPEKA services (id "g26-..."): intercity = Jawa routes whose route_desc class includes ARGO, EKSEKUTIF,
    EKSEKUTIF CAMPURAN or EKONOMI JARAK JAUH, plus every Sumbagsel route.

Service model (decided here)
  * A run = one KA number, or a through journey listed in Buku Penomoran as several numbers (GTFS block_id,
    e.g. 42-43), joined into one run "42/43" when the numbers connect at the same station and the joined stop list
    never visits a station twice. A block that loops (e.g. Joglosemarkerto 233-234-235: Solo - Tegal - Solo -
    Semarang) stays as separate runs, one per KA number.
  * A service = one train name + one pair of end stations (either direction). Its stops are the union of its runs'
    stops in track order, so a run's stop list is always a subsequence of the service stops (forward or reversed).
    Runs that cannot share one order, or that take another line between the same ends (the union would zig-zag,
    > 15 % longer than the longest run), become a further service of the same name (id suffixed with its ends).
    Stops whose order the runs leave open are ordered by their position on the v1 track when one fits, else
    nearest-first.
  * stops[].m / .d (minutes since the origin / standing minutes, the ETA prior) come from one representative run
    (regular before fakultatif, then most stops): m = departure minus origin departure (arrival at the last stop),
    d = departure minus arrival. A union stop that run does not call at gets m interpolated by km and d = 0.
    The service is oriented in that run's direction.
    "mFrom" names that run's KA number.
  * stops[].q = "hanya sebagian perjalanan berhenti" when not every run calls there.
  * runs[]: {ka, fakultatif, stops: [{c, arr, dep, est}]} with arr/dep in minutes after the run's service-day
    midnight (WIB), > 1440 after midnight, exactly as the GTFS (which never resets to 00:xx).
    est = true when GAPEKA prints no time there (Berh/Sb): the time is interpolated on track km between the nearest
    printed times, rounded to the minute, arr = dep. Printed times are never changed.

Track and km
  * v1_match: the v1 train with the same name (or a known rename, see ALIAS) has a path every stop lies on
    (<= 450 m, in order): that path is sliced from the first to the last stop; km is v1 km where the stop is a v1
    stop, else the stop's projection on the path (same scale as v1).
  * v1_other_path: no name match fits, but another v1 path (same region) has every stop on it: same method.
  * straight: no v1 path fits: km = straight line x 1.2 between consecutive stops, path = the stations,
    status "approx" so the app says the route is approximate.

Stations: v1 stations are reused as they are (codes, names and coordinates all agree with the GAPEKA feed within
300 m; checked below). A station only in GAPEKA gets its coordinate and name from the GAPEKA feed's stops.txt
(which took them from repo OSM / KRL data, see that feed's README) with s = "gapeka_feed", no city/province.
"""
import collections
import csv
import datetime
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
V1 = os.path.join(ROOT, 'assets/intercity/intercity_v1.json')
OUT = os.path.join(ROOT, 'assets/intercity/intercity_v2.json')
FEEDS = [
    # (folder, region in the asset, take every route?)
    ('supabase/data/gtfs-gapeka-2026-jawa', 'jawa', False),
    ('supabase/data/gtfs-gapeka-2026-sumbagsel', 'sumatra', True),
]
INTERCITY_CLASSES = {'ARGO', 'EKSEKUTIF', 'EKSEKUTIF CAMPURAN', 'EKONOMI JARAK JAUH'}
EXPECTED_TRIPS = {'jawa': 319, 'sumatra': 10}
VALID_FROM = '2026-12-01'
V1_UNTIL = '2026-11-30'
ON_TRACK_M = 450.0
# GAPEKA name -> v1 id where the name changed between the two sources.
ALIAS = {
    'Blambangan': 'blambangan-ekspres',
    'Dharmawangsa': 'dharmawangsa-ekspres',
    'Gayabaru Selatan': 'gaya-baru-malam-selatan',
    'Tawangjaya Premium': 'tawang-jaya-premium',
    'Ambarawa': 'ambarawa-ekspres',
    'Exspres Rajabasa': 'rajabasa',
    'Fajar Utama YK': 'fajar-dan-senja-utama-yogyakarta',
    'Senja Utama YK': 'fajar-dan-senja-utama-yogyakarta',
    'Fajar Utama Solo': 'fajar-dan-senja-utama-solo',
    'Senja Utama Solo': 'fajar-dan-senja-utama-solo',
    'Gajayana Fakultatif': 'gajayana',
    'Parahyangan Fakultatif': 'parahyangan',
}
PARTIAL_STOP = 'hanya sebagian perjalanan berhenti'


def hv(a, b, c, d):
    R = 6371000; p = math.pi / 180
    x = math.sin((c - a) * p / 2) ** 2 + math.cos(a * p) * math.cos(c * p) * math.sin((d - b) * p / 2) ** 2
    return 2 * R * math.asin(math.sqrt(x))


def slug(n):
    return re.sub(r'[^a-z0-9]+', '-', n.lower()).strip('-')


def minutes(t):
    if not t:
        return None
    h, m, s = (int(x) for x in t.split(':'))
    assert s == 0, t
    return h * 60 + m


def read(path):
    with open(path, encoding='utf-8', newline='') as f:
        return list(csv.DictReader(f))


# ---------------------------------------------------------------- v1 input
v1 = json.load(open(V1, encoding='utf-8'))
stations = dict(v1['stations'])
v1_by_id = {s['id']: s for s in v1['services']}

# ---------------------------------------------------------------- GAPEKA runs
runs = []            # dicts: name, region, classes, ka, fakultatif, stops [{c, arr, dep}] (arr/dep None = no time)
trip_counts = collections.Counter()
blocks_split = []
new_station_src = {}
printed = []         # (region, run ka, KA number, first member?, last member?, GTFS rows) for the final cross-check
for folder, region, take_all in FEEDS:
    d = os.path.join(ROOT, folder)
    routes = {r['route_id']: r for r in read(os.path.join(d, 'routes.txt'))}

    def classes_of(r):
        return [x.strip() for x in r['route_desc'].replace('Kelas GAPEKA:', '').split('/')]
    keep = {rid for rid, r in routes.items() if take_all or set(classes_of(r)) & INTERCITY_CLASSES}
    trips = [t for t in read(os.path.join(d, 'trips.txt')) if t['route_id'] in keep]
    trip_counts[region] += len(trips)
    feed_stops = {s['stop_id']: s for s in read(os.path.join(d, 'stops.txt'))}
    st = collections.defaultdict(list)
    for r in read(os.path.join(d, 'stop_times.txt')):
        st[r['trip_id']].append(r)
    for rows in st.values():
        rows.sort(key=lambda r: int(r['stop_sequence']))

    def trip_stops(t):
        out = []
        for r in st[t['trip_id']]:
            out.append({'c': r['stop_id'], 'arr': minutes(r['arrival_time']), 'dep': minutes(r['departure_time'])})
        assert out[0]['dep'] is not None and out[-1]['arr'] is not None, t['trip_id']
        return out

    # stations: reuse v1, else take from the feed
    for t in trips:
        for r in st[t['trip_id']]:
            c = r['stop_id']; s = feed_stops[c]
            la, lo = float(s['stop_lat']), float(s['stop_lon'])
            if c in v1['stations']:
                v = v1['stations'][c]
                off = hv(la, lo, v['la'], v['lo'])
                assert off < 300, (c, off)
            elif c not in stations:
                stations[c] = {'n': s['stop_name'], 'la': round(la, 6), 'lo': round(lo, 6), 'r': region,
                               's': 'gapeka_feed', 'c': '', 'p': ''}
                new_station_src[c] = folder

    groups = collections.defaultdict(list)
    singles = []
    for t in trips:
        (groups[t['block_id']] if t['block_id'] else singles).append(t)
    pieces = [[t] for t in singles]
    for bid, members in groups.items():
        members.sort(key=lambda t: trip_stops(t)[0]['dep'])
        joined = trip_stops(members[0])
        ok = True
        for nxt in members[1:]:
            s2 = trip_stops(nxt)
            if joined[-1]['c'] != s2[0]['c']:
                ok = False; break
            junction = {'c': s2[0]['c'], 'arr': joined[-1]['arr'], 'dep': s2[0]['dep']}
            joined = joined[:-1] + [junction] + s2[1:]
        codes = [s['c'] for s in joined]
        if ok and len(codes) == len(set(codes)):
            pieces.append(members)
        else:
            blocks_split.append((bid, [m['trip_short_name'] for m in members],
                                 'loops back' if ok else 'does not connect'))
            pieces += [[m] for m in members]

    for members in pieces:
        stops = trip_stops(members[0])
        for nxt in members[1:]:
            s2 = trip_stops(nxt)
            stops = stops[:-1] + [{'c': s2[0]['c'], 'arr': stops[-1]['arr'], 'dep': s2[0]['dep']}] + s2[1:]
        route = routes[members[0]['route_id']]
        assert len({m['route_id'] for m in members}) == 1
        fak = {m['service_id'].endswith('_FAKULTATIF') for m in members}
        assert len(fak) == 1, members
        ka = '/'.join(m['trip_short_name'] for m in members)
        for i, m in enumerate(members):
            printed.append((region, ka, m['trip_short_name'], i == 0, i == len(members) - 1, trip_stops(m)))
        runs.append({'name': route['route_short_name'], 'region': region, 'classes': classes_of(route),
                     'ka': '/'.join(m['trip_short_name'] for m in members), 'fakultatif': fak.pop(),
                     'stops': stops, 'n_trips': len(members)})

assert dict(trip_counts) == EXPECTED_TRIPS, trip_counts
assert sum(r['n_trips'] for r in runs) == sum(EXPECTED_TRIPS.values())

# ---------------------------------------------------------------- geometry helpers
def xy(lat0):
    kx = 111320 * math.cos(lat0 * math.pi / 180); ky = 110574
    return kx, ky


class Path:
    def __init__(self, pts):
        self.pts = pts
        self.cum = [0.0]
        for a, b in zip(pts, pts[1:]):
            self.cum.append(self.cum[-1] + hv(a[0], a[1], b[0], b[1]))
        self.length = self.cum[-1]

    def candidates(self, lat, lon):
        """Positions (along m, offset m) where the point is within ON_TRACK_M of the path: the best of each run of
        consecutive close segments."""
        kx, ky = xy(lat)
        out = []; cur = None
        for i in range(len(self.pts) - 1):
            a, b = self.pts[i], self.pts[i + 1]
            ax, ay = (a[1] - lon) * kx, (a[0] - lat) * ky
            bx, by = (b[1] - lon) * kx, (b[0] - lat) * ky
            dx, dy = bx - ax, by - ay; L = dx * dx + dy * dy
            t = 0.0 if L == 0 else max(0.0, min(1.0, (-ax * dx - ay * dy) / L))
            off = math.hypot(ax + dx * t, ay + dy * t)
            if off <= ON_TRACK_M:
                along = self.cum[i] + (self.cum[i + 1] - self.cum[i]) * t
                if cur is None or off < cur[1]:
                    cur = (along, off)
            elif cur is not None:
                out.append(cur); cur = None
        if cur is not None:
            out.append(cur)
        return out

    def point_at(self, along):
        for i in range(1, len(self.cum)):
            if along <= self.cum[i] or i == len(self.cum) - 1:
                span = self.cum[i] - self.cum[i - 1]
                t = 0 if span == 0 else max(0.0, min(1.0, (along - self.cum[i - 1]) / span))
                a, b = self.pts[i - 1], self.pts[i]
                return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]

    def slice(self, a, b):
        pts = [self.point_at(a)]
        pts += [list(p) for p, c in zip(self.pts, self.cum) if a < c < b]
        pts.append(self.point_at(b))
        return pts


def is_subsequence(seq, order):
    it = iter(order)
    return all(c in it for c in seq)


def fit(path, codes, seqs):
    """Places the stops on the path: each at its closest point (<= ON_TRACK_M), then ordered by position along the
    path. Returns (order, alongs, worst offset m), or None when a stop is off the path, two stops land on the same
    point, or the order contradicts a run's own stop order."""
    pos = {}
    for c in codes:
        s = stations[c]
        cands = path.candidates(s['la'], s['lo'])
        if not cands:
            return None
        pos[c] = min(cands, key=lambda x: x[1])
    order = sorted(codes, key=lambda c: pos[c][0])
    alongs = [pos[c][0] for c in order]
    if any(b - a < 1.0 for a, b in zip(alongs, alongs[1:])):
        return None
    if not all(is_subsequence(q, order) for q in seqs):
        return None
    return order, alongs, max(pos[c][1] for c in codes)


v1_paths = []
for s in v1['services']:
    pts = [tuple(p) for p in s['path']]
    for rev in (False, True):
        p = Path(pts[::-1] if rev else pts)
        v1_paths.append((s, rev, p))


def place_on_v1(codes, seqs, region, preferred):
    """Best-fitting v1 path for the stops: (v1 service, reversed, Path, order, alongs, worst offset m) or None.
    Only paths that keep codes[0] first are tried, so the service keeps its representative run's direction."""
    best = None
    for s, rev, p in v1_paths:
        if s['region'] != region:
            continue
        if preferred is not None and s['id'] != preferred:
            continue
        r = fit(p, codes, seqs)
        if r is None or r[0][0] != codes[0]:
            continue
        if best is None or r[2] < best[5]:
            best = (s, rev, p, r[0], r[1], r[2])
    return best


# ---------------------------------------------------------------- group runs into services
def oriented(run, forward_first):
    return run['stops'] if run['stops'][0]['c'] == forward_first else run['stops'][::-1]


def merge_order(seqs):
    """Topological merge of stop sequences (all starting at the same station); None when they disagree. Stops whose
    order the runs leave open (one run calls at X, another at Y) are put nearest-first from the last stop placed,
    which follows the line; place_on_v1 re-orders them by track position when a v1 path fits."""
    nodes = []; seen = set()
    for q in seqs:
        for c in q:
            if c not in seen:
                seen.add(c); nodes.append(c)
    succ = collections.defaultdict(set); indeg = collections.Counter({c: 0 for c in nodes})
    for q in seqs:
        for a, b in zip(q, q[1:]):
            if b not in succ[a]:
                succ[a].add(b); indeg[b] += 1
    ready = [c for c in nodes if indeg[c] == 0]; out = []
    while ready:
        if out:
            a = stations[out[-1]]
            ready.sort(key=lambda c: hv(a['la'], a['lo'], stations[c]['la'], stations[c]['lo']))
        c = ready.pop(0); out.append(c)
        for b in succ[c]:
            indeg[b] -= 1
            if indeg[b] == 0:
                ready.append(b)
    return out if len(out) == len(nodes) else None


def representative(rs):
    return min(rs, key=lambda r: (r['fakultatif'], -len(r['stops']),
                                  sum(1 for s in r['stops'] if s['arr'] is None), r['stops'][0]['dep'], r['ka']))


by_corridor = collections.defaultdict(list)
for r in runs:
    by_corridor[(r['name'], frozenset((r['stops'][0]['c'], r['stops'][-1]['c'])))].append(r)

def line_length(codes):
    return sum(hv(stations[x]['la'], stations[x]['lo'], stations[y]['la'], stations[y]['lo'])
               for x, y in zip(codes, codes[1:]))


def cluster_order(members):
    """Merged stop order of runs that can share one service, or None. Runs with the same end stations can still
    take different lines (Joglosemarkerto 233 Solo - Semarang - Tegal and 234 Tegal - Purwokerto - Solo): the merge
    then zig-zags between the two lines, so a union clearly longer (> 15 %) than its longest run is refused."""
    rep = representative(members)
    order = merge_order([[s['c'] for s in oriented(r, rep['stops'][0]['c'])] for r in members])
    if order is None:
        return None
    longest = max(line_length([s['c'] for s in r['stops']]) for r in members)
    return order if line_length(order) <= 1.15 * longest else None


groups = []   # (name, rep, runs, order)
split_groups = 0
for (name, _), rs in sorted(by_corridor.items(), key=lambda kv: (kv[0][0], sorted(kv[0][1]))):
    clusters = []
    for r in sorted(rs, key=lambda r: (-len(r['stops']), r['stops'][0]['dep'], r['ka'])):
        for cl in clusters:
            if cluster_order(cl + [r]) is not None:
                cl.append(r); break
        else:
            clusters.append([r])
    split_groups += len(clusters) - 1
    for cl in clusters:
        groups.append((name, representative(cl), cl, cluster_order(cl)))

# ---------------------------------------------------------------- build services
def classes_label(cl):
    return sorted({c.title() for c in cl})


def tier(cl):
    s = set(cl)
    if 'ARGO' in s:
        return 'A'
    if s <= {'EKONOMI', 'EKONOMI JARAK JAUH'}:
        return 'C'
    return 'B'


services_out = []
ids = set(v1_by_id)
km_cases = collections.Counter(); km_case_runs = collections.Counter()
est_stops = 0; total_run_stops = 0
name_count = collections.Counter(g[0] for g in groups)
for name, rep, rs, order in groups:
    region = rep['region']
    preferred = ALIAS.get(name, slug(name))
    preferred = preferred if preferred in v1_by_id else None
    seqs = [[s['c'] for s in oriented(r, order[0])] for r in rs]
    placed = place_on_v1(order, seqs, region, preferred) if preferred else None
    case = 'v1_match' if placed else None
    if placed is None:
        placed = place_on_v1(order, seqs, region, None)
        case = 'v1_other_path' if placed else 'straight'
    status, issues = 'ok', []
    if placed is not None:
        vs, rev, p, order, alongs, _ = placed
        scale = vs['km'] * 1000 / p.length
        v1km = {s['c']: (vs['km'] - s['km'] if rev else s['km']) for s in vs['stops']}
        raw = [v1km[c] if c in v1km else a * scale / 1000 for c, a in zip(order, alongs)]
        if any(b <= a for a, b in zip(raw, raw[1:])):
            raw = [a * scale / 1000 for a in alongs]
        km = [round(x - raw[0], 1) for x in raw]
        path = p.slice(alongs[0], alongs[-1])
        status = vs['status']; issues = list(vs['issues'])
        src = vs['id']
    else:
        km = [0.0]
        for a, b in zip(order, order[1:]):
            km.append(km[-1] + hv(stations[a]['la'], stations[a]['lo'], stations[b]['la'], stations[b]['lo']) * 1.2 / 1000)
        km = [round(x, 1) for x in km]
        path = [[stations[c]['la'], stations[c]['lo']] for c in order]
        status = 'approx'
        issues = ['no v1 OSM track covers this route: straight lines between stations x1.2, km approximate']
        src = None
    assert all(b > a for a, b in zip(km, km[1:])), (name, order, km)
    km_cases[case] += 1; km_case_runs[case] += len(rs)
    kmof = dict(zip(order, km))

    # interpolate missing times on track km, per run
    out_runs = []
    for r in sorted(rs, key=lambda r: (r['stops'][0]['dep'], r['ka'])):
        st = [dict(s) for s in r['stops']]
        timed = [i for i, s in enumerate(st) if s['arr'] is not None and s['dep'] is not None]
        assert timed[0] == 0 and timed[-1] == len(st) - 1
        for lo, hi in zip(timed, timed[1:]):
            t0, t1 = st[lo]['dep'], st[hi]['arr']
            d0, d1 = kmof[st[lo]['c']], kmof[st[hi]['c']]
            prev = t0
            for i in range(lo + 1, hi):
                k = (kmof[st[i]['c']] - d0) / (d1 - d0)
                v = min(max(round(t0 + k * (t1 - t0)), prev), t1)
                st[i]['arr'] = st[i]['dep'] = v; st[i]['est'] = True; prev = v
        for s in st:
            s.setdefault('est', False)
            assert s['c'] in stations
        # times never go back
        seq = [x for s in st for x in (s['arr'], s['dep'])]
        assert all(b >= a for a, b in zip(seq, seq[1:])), (name, r['ka'], seq)
        est_stops += sum(1 for s in st if s['est']); total_run_stops += len(st)
        out_runs.append({'ka': r['ka'], 'fakultatif': r['fakultatif'],
                         'stops': [{'c': s['c'], 'arr': s['arr'], 'dep': s['dep'], 'est': s['est']} for s in st]})

    # m / d from the representative run (oriented like the service)
    rep_out = next(x for x in out_runs if x['ka'] == rep['ka'])
    assert rep_out['stops'][0]['c'] == order[0], (name, rep['ka'])
    at = {s['c']: s for s in rep_out['stops']}
    dep0 = rep_out['stops'][0]['dep']
    md = {}
    for i, c in enumerate(order):
        if c in at:
            s = at[c]
            if i == 0:
                md[c] = (0, 0)
            elif i == len(order) - 1:
                md[c] = (s['arr'] - dep0, 0)
            else:
                md[c] = (s['dep'] - dep0, s['dep'] - s['arr'])
    for i, c in enumerate(order):
        if c in md:
            continue
        j = max(k for k in range(i) if order[k] in md)
        h = min(k for k in range(i + 1, len(order)) if order[k] in md)
        ma = md[order[j]][0]; mb = md[order[h]][0] - md[order[h]][1]
        f = (km[i] - km[j]) / (km[h] - km[j])
        md[c] = (round(ma + f * (mb - ma)), 0)
    served = collections.Counter(s['c'] for x in out_runs for s in x['stops'])
    stops = []
    for c in order:
        e = {'c': c, 'km': kmof[c], 'm': md[c][0], 'd': md[c][1]}
        if served[c] < len(out_runs):
            e['q'] = PARTIAL_STOP
        stops.append(e)
    assert all(b['m'] >= a['m'] for a, b in zip(stops, stops[1:])), name

    sid = 'g26-' + slug(name)
    if name_count[name] > 1 or sid in ids:
        sid = f"{sid}-{order[0].lower()}-{order[-1].lower()}"
    n = 2
    while sid in ids:
        sid = f"{sid}-{n}"; n += 1
    ids.add(sid)
    cl = sorted({c for r in rs for c in r['classes']})
    svc = {'id': sid, 'name': name, 'classes': classes_label(cl), 'tier': tier(cl), 'from': order[0], 'to': order[-1],
           'km': km[-1], 'region': region, 'status': status, 'issues': issues, 'track': case,
           'stops': stops, 'path': [[round(a, 5), round(b, 5)] for a, b in path], 'mFrom': rep['ka'],
           'runs': out_runs}
    if src:
        svc['trackFrom'] = src
    services_out.append(svc)

# ---------------------------------------------------------------- v1 services, kept for before VALID_FROM
sumbagsel_codes = {s['stop_id'] for s in read(os.path.join(ROOT, FEEDS[1][0], 'stops.txt'))}
v1_kept = []
for s in v1['services']:
    s = dict(s)
    covered = s['region'] == 'jawa' or any(x['c'] in sumbagsel_codes for x in s['stops'])
    if covered:
        s['until'] = V1_UNTIL
    v1_kept.append(s)

# Cross-check against the GTFS: every printed time is in the asset unchanged, on the run carrying that KA number.
# A joined run takes its junction arrival from the earlier number and departure from the later one.
run_by_ka = {(s['region'], r['ka']): r for s in services_out for r in s['runs']}
assert len(run_by_ka) == sum(len(s['runs']) for s in services_out), 'run KA labels must be unique per region'
checked = 0
for region, ka, number, first_member, last_member, rows in printed:
    stops = {x['c']: x for x in run_by_ka[(region, ka)]['stops']}
    for i, row in enumerate(rows):
        x = stops[row['c']]
        if row['arr'] is None:
            assert x['est'], (ka, row)
            continue
        assert not x['est'], (ka, row)
        if not (i == 0 and not first_member):
            assert x['arr'] == row['arr'], (ka, number, row, x)
        if not (i == len(rows) - 1 and not last_member):
            assert x['dep'] == row['dep'], (ka, number, row, x)
        checked += 1
assert sum(len(r['ka'].split('/')) for r in run_by_ka.values()) == sum(EXPECTED_TRIPS.values())

all_services = v1_kept + services_out
used = {x['c'] for s in all_services for x in s['stops']}
missing = used - set(stations)
assert not missing, missing
data = {
    'version': 2,
    'generated': datetime.date.today().isoformat(),
    'validFrom': VALID_FROM,
    'source': ('Timetable: GAPEKA 2026, KP DJKA 116 Tahun 2026 (Jawa) and KP DJKA 119 Tahun 2026 (Sumatera Bagian '
               'Selatan), Direktorat Jenderal Perkeretaapian, valid from 2026-12-01, via the repo GTFS feeds '
               'supabase/data/gtfs-gapeka-2026-*. Runs carry the printed times; est=true marks a stop where GAPEKA '
               'prints no time (interpolated on track km). GAPEKA also lists operational stops (crossings, crew '
               'change) without saying which serve passengers. Tracks: OpenStreetMap paths from v1; services with '
               '"track":"straight" use straight lines x1.2 (approximate). Services with "until" are the v1 '
               'estimates (Wikipedia list, Gapeka 2023-2025), shown only up to that date.'),
    'speeds': v1['speeds'],
    'stations': {c: stations[c] for c in sorted(used)},
    'services': all_services,
}
with open(OUT, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))

# ---------------------------------------------------------------- summary
n_runs = sum(len(s['runs']) for s in services_out)
joined = sum(1 for s in services_out for r in s['runs'] if '/' in r['ka'])
ka_numbers = sum(len(r['ka'].split('/')) for s in services_out for r in s['runs'])
new_used = sorted(c for c in used if c not in v1['stations'])
print(f"wrote {os.path.relpath(OUT, ROOT)} ({os.path.getsize(OUT)} bytes)")
print(f"GTFS intercity trips: {dict(trip_counts)} = {sum(trip_counts.values())}")
print(f"GAPEKA services: {len(services_out)}  runs: {n_runs}  (joined through journeys: {joined}; "
      f"KA numbers in runs: {ka_numbers})  fakultatif runs: "
      f"{sum(1 for s in services_out for r in s['runs'] if r['fakultatif'])}")
print(f"blocks kept as separate runs: {len(blocks_split)}")
for b in blocks_split:
    print('   ', b)
print(f"extra services from same-name, same-ends runs on different lines or in conflicting order: {split_groups}")
print(f"km/path cases (services): {dict(km_cases)}   (runs): {dict(km_case_runs)}")
print(f"run stops: {total_run_stops}, estimated (no printed time): {est_stops}; printed GTFS stop times "
      f"cross-checked unchanged: {checked}")
print(f"v1 services kept: {len(v1_kept)} ({sum(1 for s in v1_kept if 'until' in s)} with until {V1_UNTIL})")
print(f"stations: {len(data['stations'])} total, {len(data['stations']) - len(new_used)} reused from v1, "
      f"{len(new_used)} new from the GAPEKA feed stops.txt")
print('straight-line services:', [s['id'] for s in services_out if s['track'] == 'straight'])
print('other-path services:', [(s['id'], s['trackFrom']) for s in services_out if s['track'] == 'v1_other_path'])
print('v1 services with no GAPEKA 2026 service (name/alias):',
      sorted(set(v1_by_id) - {ALIAS.get(s['name'], slug(s['name'])) for s in services_out}))
