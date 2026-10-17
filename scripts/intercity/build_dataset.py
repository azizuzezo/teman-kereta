import json, math, glob, collections, sys, re, datetime
S = sys.argv[1]; OUT = sys.argv[2]

def hv(a, b, c, d):
    R = 6371000; p = math.pi / 180
    x = math.sin((c - a) * p / 2) ** 2 + math.cos(a * p) * math.cos(c * p) * math.sin((d - b) * p / 2) ** 2
    return 2 * R * math.asin(math.sqrt(x))

# --- rail vertices (any rail way) for track-offset checks ---
grid = collections.defaultdict(list)
for f in glob.glob(f'{S}/rail_java*.json') + glob.glob(f'{S}/rail_sum*.json'):
    for w in json.load(open(f, encoding='utf-8'))['elements']:
        t = w.get('tags', {})
        if t.get('railway') != 'rail' or t.get('usage') == 'industrial' or (t.get('service') and t.get('usage') != 'main'): continue
        g = w['geometry']
        # densify so spacing <= ~40 m
        for a, b in zip(g, g[1:]):
            n = max(1, int(hv(a['lat'], a['lon'], b['lat'], b['lon']) // 40))
            for i in range(n + 1):
                la = a['lat'] + (b['lat'] - a['lat']) * i / n; lo = a['lon'] + (b['lon'] - a['lon']) * i / n
                grid[(int(la * 100), int(lo * 100))].append((la, lo))
def track_offset(lat, lon):
    cx, cy = int(lat * 100), int(lon * 100); best = 1e18
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for p in grid.get((cx + dx, cy + dy), ()):
                d = hv(lat, lon, p[0], p[1])
                if d < best: best = d
    return best

# --- city / province per station (Nominatim reverse geocode, cleaned) ---
raw_cities = json.load(open(f'{S}/station_cities.json', encoding='utf-8'))
CITY_FIX = {  # lookups that came back wrong or too coarse
    'GMR': ('Jakarta Pusat', 'DKI Jakarta'), 'PSE': ('Jakarta Pusat', 'DKI Jakarta'), 'JNG': ('Jakarta Timur', 'DKI Jakarta'),
    'WK': ('Ngawi', 'Jawa Timur'), 'NGW': ('Ngawi', 'Jawa Timur'), 'ARB': ('Deli Serdang', 'Sumatera Utara'),
}
PROVINCE = {'Daerah Istimewa Yogyakarta': 'DI Yogyakarta', 'Daerah Khusus Ibukota Jakarta': 'DKI Jakarta'}
def place(code):
    if code in CITY_FIX: return CITY_FIX[code]
    r = raw_cities.get(code, {})
    city = r.get('city', '')
    for pre in ('Kota ', 'Kabupaten '):
        if city.startswith(pre): city = city[len(pre):]
    return city, PROVINCE.get(r.get('state', ''), r.get('state', ''))

# --- inputs ---
verif = {v['code']: v for v in json.load(open(f'{S}/coords_verification.json', encoding='utf-8'))}
services = []
for reg in ('jawa', 'sumatra'):
    for r in json.load(open(f'{S}/ka_resolved_{reg}.json', encoding='utf-8')):
        r['region'] = reg; services.append(r)

# station table with final coordinate decision
names = collections.defaultdict(set)
for r in services:
    for s in r['stops']: names[s['code']].add(s['name'])
assert all(len(v) == 1 for v in names.values()), {k: v for k, v in names.items() if len(v) > 1}
stations = {}; review = []
for code, v in verif.items():
    lat, lon = v['lat'], v['lon']; status = v['status']; note = ''
    off_osm = track_offset(lat, lon)
    if status == 'verified':
        final = (lat, lon); st = 'verified'
    elif status == 'disputed':
        off_wd = track_offset(v['wd_lat'], v['wd_lon'])
        if off_osm <= 90 and off_wd > 150: final = (lat, lon); st = 'resolved_osm_on_track'
        elif off_wd <= 90 and off_osm > 150: final = (v['wd_lat'], v['wd_lon']); st = 'resolved_wikidata_on_track'
        else: final = (lat, lon); st = 'needs_review'
        note = f"OSM {off_osm:.0f} m / Wikidata {off_wd:.0f} m from track; sources differ {v['diff_m']} m"
    else:
        if off_osm <= 120: final = (lat, lon); st = 'single_source_on_track'
        else: final = (lat, lon); st = 'needs_review'; note = f'OSM point {off_osm:.0f} m from track, no second source'
    city, province = place(code)
    stations[code] = {'n': v['name'], 'la': round(final[0], 6), 'lo': round(final[1], 6), 'r': v['region'], 's': st, 'c': city, 'p': province}
    if st in ('needs_review', 'resolved_osm_on_track', 'resolved_wikidata_on_track', 'single_source_on_track'):
        review.append((code, v['name'], st, note))

# --- helpers ---
def slug(n): return re.sub(r'[^a-z0-9]+', '-', n.lower()).strip('-')
def tier(r):
    cl = {c.lower() for c in r['classes']}
    if r['name'].startswith('Argo') or cl & {'luxury', 'compartment suite', 'priority', 'panoramic'}: return 'A'
    if cl <= {'ekonomi'}: return 'C'
    return 'B'
CRUISE = {'A': 82.0, 'B': 72.0, 'C': 62.0}      # km/h between stops (prior estimate)
DWELL = {'A': 3.0, 'B': 4.0, 'C': 5.0}          # minutes at an intermediate stop
use = collections.Counter(s['code'] for r in services for s in r['stops'])
hubs = {c for c, n in use.items() if n >= 12}

def dp(points, tol):
    # Douglas-Peucker in local metres
    if len(points) < 3: return points
    lat0 = points[0][0]; kx = 111320 * math.cos(lat0 * math.pi / 180); ky = 110574
    xy = [(p[1] * kx, p[0] * ky) for p in points]
    keep = [False] * len(points); keep[0] = keep[-1] = True; stack = [(0, len(points) - 1)]
    while stack:
        a, b = stack.pop()
        if b - a < 2: continue
        ax, ay = xy[a]; bx, by = xy[b]; dx, dy = bx - ax, by - ay; L = dx * dx + dy * dy
        best, bi = -1, -1
        for i in range(a + 1, b):
            px, py = xy[i]
            t = 0 if L == 0 else max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / L))
            d = math.hypot(px - (ax + t * dx), py - (ay + t * dy))
            if d > best: best, bi = d, i
        if best > tol: keep[bi] = True; stack += [(a, bi), (bi, b)]
    return [p for p, k in zip(points, keep) if k]

out_services = []; ids = set()
for r in services:
    t = tier(r)
    sid = slug(r['name']); assert sid not in ids, sid; ids.add(sid)
    stops = []; clock = 0.0
    qual = {}
    for q in r.get('qualifiers', []): qual.setdefault(slug(q[0]), q[1])
    for i, s in enumerate(r['stops']):
        if i > 0:
            prev = r['stops'][i - 1]
            leg_km = s['km'] - prev['km']
            straight = hv(stations[prev['code']]['la'], stations[prev['code']]['lo'], stations[s['code']]['la'], stations[s['code']]['lo'])
            ratio = (leg_km * 1000.0) / max(straight, 1.0)
            # winding (mountain) legs are slower: ratio 1.15 is a normal curve allowance
            m = max(0.55, 1.0 / (1.0 + 0.6 * max(0.0, ratio - 1.15)))
            clock += leg_km / (CRUISE[t] * m) * 60.0
            if i < len(r['stops']) - 1: dwell = DWELL[t] + (4.0 if s['code'] in hubs else 0.0)
            else: dwell = 0.0
            clock += dwell
        else: dwell = 0.0
        e = {'c': s['code'], 'km': s['km'], 'm': round(clock), 'd': round(dwell)}
        if slug(s['name']) in qual: e['q'] = qual[slug(s['name'])]
        stops.append(e)
    path = [[p[0], p[1]] for p in dp(r['path'], 40)]
    out_services.append({'id': sid, 'name': r['name'], 'classes': sorted(set(r['classes'])), 'tier': t, 'from': r['stops'][0]['code'],
                         'to': r['stops'][-1]['code'], 'km': r['total_km'], 'region': r['region'], 'status': r['status'],
                         'issues': r['issues'], 'stops': stops, 'path': [[round(a, 5), round(b, 5)] for a, b in path]})

used_codes = {s['c'] for sv in out_services for s in sv['stops']}
data = {'version': 1, 'generated': datetime.date.today().isoformat(),
        'source': 'Routes: Wikipedia "Daftar kereta api di Indonesia" (community list, Gapeka 2023-2025), validated against OpenStreetMap track geometry. Stations: OpenStreetMap, cross-checked with Wikidata. Times are ESTIMATES (no official timetable).',
        'speeds': {'cruiseKmh': CRUISE, 'dwellMinutes': DWELL, 'hubExtraDwell': 4.0, 'windingPenalty': 'speed x 1/(1+0.6*max(0,track/straight-1.15)), min 0.55'},
        'stations': {c: stations[c] for c in sorted(used_codes)}, 'services': out_services}
json.dump(data, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
import os
print('services', len(out_services), 'stations', len(data['stations']), 'bytes', os.path.getsize(OUT))
print(collections.Counter(s['s'] for s in data['stations'].values()))
print(collections.Counter(s['tier'] for s in out_services))
print('points', sum(len(s['path']) for s in out_services))
for c in review: print('REVIEW', c)
json.dump(review, open(f'{S}/station_review.json', 'w', encoding='utf-8'), ensure_ascii=False)
