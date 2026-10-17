import json, csv, math, heapq, re, sys, collections, glob, unicodedata
S = sys.argv[1]; REGION = sys.argv[2]  # 'jawa' | 'sumatra'
STCSV = 'C:/Projet/Teman Kereta/supabase/data/gtfs-antarkota/candidates/stations_osm_candidates.csv'

def hv(a, b, c, d):
    R = 6371000; p = math.pi / 180
    x = math.sin((c - a) * p / 2) ** 2 + math.cos(a * p) * math.cos(c * p) * math.sin((d - b) * p / 2) ** 2
    return 2 * R * math.asin(math.sqrt(x))

def norm(n):
    n = unicodedata.normalize('NFKD', n).encode('ascii', 'ignore').decode().lower()
    n = re.sub(r'\bstasiun\b', '', n)
    n = re.sub(r'[^a-z0-9 ]', ' ', n)
    return re.sub(r'\s+', ' ', n).strip()

# --- stations ---
stations = [r for r in csv.DictReader(open(STCSV, encoding='utf-8')) if r['region'] == REGION]
for r in stations: r['lat'] = float(r['lat']); r['lon'] = float(r['lon'])
byname = collections.defaultdict(list)
for r in stations: byname[norm(r['name'])].append(r)
ALIAS = {  # Wikipedia name -> OSM name (normalized)
    'pasar senen': 'pasar senen', 'solo balapan': 'solo balapan', 
    'surabaya gubeng': 'surabaya gubeng',  'semarang poncol': 'semarang poncol',
    'semarang tawang': 'semarang tawang', 'cirebon prujakan': 'cirebon prujakan', 'purwosari': 'purwosari',
    'lubuk linggau': 'lubuklinggau', 'rantauprapat': 'rantau prapat', 'puluraja': 'pulu raja', 'labuanratu': 'labuhanratu', 'blimbing pendopo': 'belimbing pendopo',
    'lubukpakam': 'lubuk pakam',
}

# --- rail graph ---
adj = collections.defaultdict(list)
files = sorted(glob.glob(f'{S}/rail_java*.json')) if REGION == 'jawa' else sorted(glob.glob(f'{S}/rail_sum*.json'))
def key(p): return (round(p['lat'], 5), round(p['lon'], 5))
for f in files:
    for w in json.load(open(f, encoding='utf-8'))['elements']:
        t = w.get('tags', {})
        if t.get('railway') != 'rail' or t.get('usage') == 'industrial': continue
        if t.get('service') in ('yard', 'siding', 'spur', 'crossover') and t.get('usage') != 'main': continue
        g = w['geometry']
        for a, b in zip(g, g[1:]):
            ka, kb = key(a), key(b)
            if ka == kb: continue
            dd = hv(a['lat'], a['lon'], b['lat'], b['lon'])
            adj[ka].append((kb, dd)); adj[kb].append((ka, dd))
# keep only the main network: drop small isolated fragments (stub sidings, gaps)
comp = {}; sizes = []
for v0 in adj:
    if v0 in comp: continue
    cid = len(sizes); stack = [v0]; comp[v0] = cid; n = 0
    while stack:
        u = stack.pop(); n += 1
        for w2, _ in adj[u]:
            if w2 not in comp: comp[w2] = cid; stack.append(w2)
    sizes.append(n)
print('components', len(sizes), sorted(sizes, reverse=True)[:8], file=sys.stderr)
MIN_COMP = 150
verts = [v for v in adj if sizes[comp[v]] >= MIN_COMP]
grid = collections.defaultdict(list)
for v in verts: grid[(int(v[0] * 50), int(v[1] * 50))].append(v)
print('graph', len(verts), 'stations', len(stations), file=sys.stderr)

def snap(lat, lon):
    cx, cy = int(lat * 50), int(lon * 50)
    best = None; bd = 1e18
    for r in range(0, 8):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if max(abs(dx), abs(dy)) != r: continue
                for v in grid.get((cx + dx, cy + dy), ()):
                    d = hv(lat, lon, v[0], v[1])
                    if d < bd: bd, best = d, v
        if best is not None and bd < r * 900: break
    return best, bd

def near_set(lat, lon, radius):
    cx, cy = int(lat * 50), int(lon * 50); out = []
    for dx in range(-3, 4):
        for dy in range(-3, 4):
            for v in grid.get((cx + dx, cy + dy), ()):
                if hv(lat, lon, v[0], v[1]) <= radius: out.append(v)
    return out

for r in stations:
    r['v'], r['off'] = snap(r['lat'], r['lon'])
    r['vs'] = near_set(r['lat'], r['lon'], (r['off'] or 0) + 90)[:80] if r['v'] is not None else []

cache = {}
def dij(A, B, limit=900000):
    k = (A['code'], B['code'], A['lat'], B['lat'])
    if k in cache: return cache[k]
    srcs, dsts = set(A['vs']), set(B['vs'])
    dist = {v: 0 for v in srcs}; prev = {}; pq = [(0, v) for v in srcs]; heapq.heapify(pq)
    found = None; end = None
    while pq:
        dd, u = heapq.heappop(pq)
        if u in dsts: found = dd; end = u; break
        if dd > dist.get(u, 1e18) or dd > limit: continue
        for v, w in adj[u]:
            nd = dd + w
            if nd < dist.get(v, 1e18):
                dist[v] = nd; prev[v] = u; heapq.heappush(pq, (nd, v))
    if found is None:
        cache[k] = (None, None); return cache[k]
    path = [end]
    while path[-1] not in srcs or path[-1] in prev and False: 
        if path[-1] not in prev: break
        path.append(prev[path[-1]])
    cache[k] = (found, path[::-1]); return cache[k]

def split_top(s):
    out = []; depth = 0; cur = ''
    for ch in s:
        if ch == '(': depth += 1
        elif ch == ')': depth -= 1
        if ch == ',' and depth == 0: out.append(cur.strip()); cur = ''
        else: cur += ch
    if cur.strip(): out.append(cur.strip())
    return out

def parse_stop(tok):
    tok = re.sub(r'\s*\*.*$', '', tok).strip()
    tok = tok.rstrip('. ').strip()
    m = re.match(r'^(.*?)\s*\((.*)\)\s*$', tok)
    if m: name, qual = m.group(1).strip(), m.group(2).strip()
    else: name, qual = tok, ''
    name = re.sub(r'^\{\{\s*sta\s*\|', '', name.replace('{{cslist|', '')).strip()
    name = re.sub(r'^(dan|serta)\s+', '', name).rstrip('. ')
    return name, qual

def candidates(name):
    n = norm(name); n = ALIAS.get(n, n)
    c = byname.get(n)
    if c: return c
    # prefix match e.g. 'malang' -> 'malang' only; avoid fuzzy except exact startswith for single hits
    return []

# --- services ---
raw = json.load(open(f'{S}/ka_services_raw.json', encoding='utf-8'))
def ok(x): return x['section'].startswith('Rute') and 'Aglomerasi' not in x['section']
groups = collections.OrderedDict()
for x in raw:
    if not ok(x): continue
    sumatra = ('Sumatra Utara' in x['section'] and x['section'].endswith('Sumatra Utara')) or 'Sumatra bagian Barat' in x['section']
    if (REGION == 'sumatra') != sumatra: continue
    k = (x['name'], x['relation'], x['stops_raw'])
    groups.setdefault(k, {'name': x['name'], 'relation': x['relation'], 'stops_raw': x['stops_raw'], 'classes': []})['classes'].append(x['class'])

def parse_relation(rel):
    rel = rel.replace('\ufffd', '–')
    via = []
    m = re.search(r'\bvia\b(.*)$', rel)
    if m:
        via = [v.strip() for v in re.split(r',| dan ', m.group(1)) if v.strip()]; rel = rel[:m.start()]
    parts = re.split(r'\s*[–—-]\s*', rel.strip())
    if len(parts) < 2: return None, None, via
    return parts[0].strip(), parts[-1].strip(), via

results = []
for g in groups.values():
    issues = []; reorders = []
    o, d, via = parse_relation(g['relation'])
    if not o:
        results.append({**g, 'status': 'fail', 'issues': ['cannot parse relation']}); continue
    toks = [t for t in map(parse_stop, split_top(g['stops_raw'].split(' * ')[0]))]
    junk = [t for t in toks if len(t[0]) > 32 or re.fullmatch(r'[0-9 ]*', t[0]) or re.search(r'sedangkan|begitu|kereta api|jadwal|tidak berhenti', t[0], re.I)]
    toks = [t for t in toks if t not in junk]
    seq = [(o, '', 'origin')] + [(n, q, 'stop') for n, q in toks] + [(d, '', 'dest')]
    # drop stops identical to origin/dest or duplicates
    seen = set(); chain = []
    for n, q, role in seq:
        kk = norm(n)
        if role == 'stop' and (kk in seen or kk in (norm(o), norm(d))): continue
        seen.add(kk); chain.append((n, q, role))
    cands = []
    for n, q, role in chain:
        c = [r for r in candidates(n) if r['v'] is not None and r['off'] <= 600]
        if not c: issues.append(f'unresolved station: {n}')
        cands.append((n, q, role, c))
    resolved = [c for c in cands if c[3]]
    if len([c for c in resolved if c[2] in ('origin', 'dest')]) < 2:
        results.append({**g, 'status': 'fail', 'issues': issues + ['origin/destination unresolved']}); continue
    # DP over candidates minimising total track length
    states = [[(r, 0.0, None) for r in resolved[0][3]]]
    for i in range(1, len(resolved)):
        layer = []
        for r in resolved[i][3]:
            best = (None, 1e18, None)
            for j, (pr, cost, _) in enumerate(states[-1]):
                dd, _p = dij(pr, r)
                if dd is None: continue
                if cost + dd < best[1]: best = (r, cost + dd, j)
            layer.append(best if best[0] is not None else (r, 1e18, None))
        states.append(layer)
    # backtrack
    last = min(range(len(states[-1])), key=lambda k: states[-1][k][1])
    if states[-1][last][1] >= 1e17:
        results.append({**g, 'status': 'fail', 'issues': issues + ['no continuous track between stops']}); continue
    pick = []; k = last
    for i in range(len(states) - 1, -1, -1):
        r, cost, j = states[i][k]; pick.append(r); k = j if j is not None else 0
    pick = pick[::-1]
    # the source list is not always in rail order (a note can move a stop): swap
    # neighbours while that shortens the whole route
    def seq_cost(p):
        tot = 0.0
        for i in range(1, len(p)):
            dd, _p2 = dij(p[i - 1], p[i])
            if dd is None: return 1e18
            tot += dd
        return tot
    base = seq_cost(pick); passes = 0; improved = True
    while improved and passes < 6:
        improved = False; passes += 1
        for i in range(1, len(pick) - 2):
            cand = pick[:]; cand[i], cand[i + 1] = cand[i + 1], cand[i]
            c = seq_cost(cand)
            if c < base - 1000:
                issues_note = f'reordered {pick[i]["name"]} / {pick[i+1]["name"]}'
                pick = cand; base = c; improved = True; reorders.append(issues_note)
    # build path + checks
    stops = []; cum = 0.0; full = []
    for i, r in enumerate(pick):
        if i > 0:
            dd, path = dij(pick[i - 1], r)
            straight = hv(pick[i - 1]['lat'], pick[i - 1]['lon'], r['lat'], r['lon'])
            ratio = dd / max(straight, 1)
            if dd > 1.6 * straight + 4000 and dd > 8000: issues.append(f'detour {pick[i-1]["name"]}→{r["name"]}: track {dd/1000:.1f} km vs straight {straight/1000:.1f} km')
            cum += dd; full += path if not full else path[1:]
        stops.append({'code': r['code'], 'name': r['name'], 'lat': r['lat'], 'lon': r['lon'], 'km': round(cum / 1000, 1), 'off_m': round(r['off'])})
    # whole-route sanity: a train does not travel 2x the straight distance, and never
    # runs over the same rail twice (that is a back-and-forth through a wrong stop)
    straight_total = hv(pick[0]['lat'], pick[0]['lon'], pick[-1]['lat'], pick[-1]['lon'])
    if cum > 1.8 * straight_total + 20000:
        issues.append(f'route too long: track {cum/1000:.0f} km vs straight {straight_total/1000:.0f} km')
    vc = collections.Counter(full)
    repeated = sum(1 for v in vc.values() if v > 1)
    if repeated > 0.02 * len(vc):
        issues.append(f'route revisits track: {repeated} rail points passed twice')
    # via check
    onpath = set(full)
    for vname in via:
        vc = [r for r in candidates(vname) if r['v'] is not None]
        if vc and not any(any(x in onpath for x in r['vs']) for r in vc):
            issues.append(f'via {vname} not on computed path')
    qual = [(c[0], c[1]) for c in cands if c[1]]
    # reduce the path
    keep = [full[0]]
    for p in full[1:-1]:
        if hv(keep[-1][0], keep[-1][1], p[0], p[1]) >= 60: keep.append(p)
    keep.append(full[-1])
    results.append({'name': g['name'], 'relation': g['relation'], 'classes': g['classes'], 'status': 'ok' if not issues else 'review',
                    'issues': issues, 'reordered': reorders, 'qualifiers': qual, 'total_km': round(cum / 1000, 1), 'stops': stops,
                    'path': [[round(p[0], 5), round(p[1], 5)] for p in keep]})

out = f'{S}/ka_resolved_{REGION}.json'
json.dump(results, open(out, 'w', encoding='utf-8'), ensure_ascii=False)
c = collections.Counter(r['status'] for r in results)
print(REGION, 'routes', len(results), dict(c))
for r in results:
    if r['status'] != 'ok': print('-', r['name'], '|', r['relation'], '|', '; '.join(r['issues'])[:230])
