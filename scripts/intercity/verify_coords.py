import json, math, time, urllib.request, urllib.parse, sys
S = sys.argv[1]
UA = {'User-Agent': 'TemanKereta-coord-verify/1.0 (aziz@skor.co)'}
used = json.load(open(f'{S}/used_stations.json', encoding='utf-8'))

def hv(a, b, c, d):
    R = 6371000; p = math.pi / 180
    x = math.sin((c - a) * p / 2) ** 2 + math.cos(a * p) * math.cos(c * p) * math.sin((d - b) * p / 2) ** 2
    return 2 * R * math.asin(math.sqrt(x))

def api(params):
    u = 'https://www.wikidata.org/w/api.php?' + urllib.parse.urlencode({**params, 'format': 'json'})
    for t in range(3):
        try:
            return json.load(urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=30))
        except Exception as e:
            time.sleep(2)
    return {}

# 1) search candidates per station
cand = {}
for s in used:
    ids = []
    for q in (f"Stasiun {s['name']}", f"{s['name']} railway station"):
        r = api({'action': 'wbsearchentities', 'search': q, 'language': 'id', 'type': 'item', 'limit': 6})
        ids += [x['id'] for x in r.get('search', [])]
        time.sleep(0.15)
    cand[s['code']] = list(dict.fromkeys(ids))
allids = sorted({i for v in cand.values() for i in v})
print('candidate entities', len(allids), file=sys.stderr)

# 2) fetch coordinates (P625) in batches
coords = {}
for i in range(0, len(allids), 50):
    r = api({'action': 'wbgetentities', 'ids': '|'.join(allids[i:i + 50]), 'props': 'claims|labels|descriptions', 'languages': 'id|en'})
    for qid, e in r.get('entities', {}).items():
        c = e.get('claims', {}).get('P625')
        if not c: continue
        v = c[0]['mainsnak'].get('datavalue', {}).get('value')
        if not v: continue
        lab = (e.get('labels', {}).get('id') or e.get('labels', {}).get('en') or {}).get('value', '')
        desc = (e.get('descriptions', {}).get('id') or e.get('descriptions', {}).get('en') or {}).get('value', '')
        coords[qid] = (v['latitude'], v['longitude'], lab, desc)
    time.sleep(0.3)

out = []
for s in used:
    best = None
    for qid in cand[s['code']]:
        if qid not in coords: continue
        la, lo, lab, desc = coords[qid]
        d = hv(s['lat'], s['lon'], la, lo)
        if d <= 4000 and (best is None or d < best[0]): best = (d, qid, lab, la, lo)
    if best is None:
        out.append({**s, 'wikidata': None, 'status': 'single_source'})
    else:
        d, qid, lab, la, lo = best
        out.append({**s, 'wikidata': qid, 'wd_label': lab, 'wd_lat': la, 'wd_lon': lo, 'diff_m': round(d), 'status': 'verified' if d <= 150 else 'disputed'})
json.dump(out, open(f'{S}/coords_verification.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
import collections
print(collections.Counter(o['status'] for o in out))
for o in out:
    if o['status'] == 'disputed': print('DISPUTED', o['code'], o['name'], o['diff_m'], 'm vs', o['wd_label'])
