import json, csv, sys, collections
S, OUT = sys.argv[1], sys.argv[2]
java = json.load(open(f'{S}/java_st.json', encoding='utf-8'))['elements']
oth = json.load(open(f'{S}/other_st.json', encoding='utf-8'))['elements']
nodes = {e['id']: e for e in java + oth}.values()

def region(e):
    if e['lon'] >= 118: return 'sulawesi'
    if e['lon'] >= 105.0 and e['lat'] <= -5.8 + 0.0 or (e['lon'] >= 105 and e['lat'] < -5.8): return 'jawa'
    if e['lon'] > 104.9 and e['lat'] < -5.9: return 'jawa'
    return 'sumatra'

rows = []; dropped = collections.Counter()
for e in nodes:
    t = e.get('tags', {})
    op = t.get('operator', '')
    if 'Tanah Melayu' in op or op == 'KTM' or (e['lon'] > 100.2 and e['lat'] > 1.3):
        dropped['malaysia/singapore'] += 1; continue
    if 'name' not in t:
        dropped['no name'] += 1; continue
    code = t.get('railway:ref', '')
    reg = 'sulawesi' if e['lon'] >= 118 else ('jawa' if e['lat'] < -5.9 and e['lon'] > 104.9 and e['lon'] < 115 else 'sumatra')
    flags = []
    if not code: flags.append('no_code')
    if t.get('railway') == 'halt': flags.append('halt')
    if 'KAI Commuter' in op: flags.append('krl')
    if 'Kereta Cepat' in op or 'KCIC' in op: flags.append('hsr')
    if t.get('disused') or t.get('railway:disused') or t.get('abandoned'): flags.append('disused')
    rows.append([code, t['name'], f"{e['lat']:.6f}", f"{e['lon']:.6f}", op, reg, e['id'], '|'.join(flags)])
cnt = collections.Counter(r[0] for r in rows if r[0])
for r in rows:
    if r[0] and cnt[r[0]] > 1: r[7] = (r[7] + '|dup_code').strip('|')
rows.sort(key=lambda r: (r[5], r[1]))
with open(OUT, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, lineterminator='\n')
    w.writerow(['code', 'name', 'lat', 'lon', 'operator', 'region', 'osm_node_id', 'flags'])
    w.writerows(rows)
print('rows', len(rows), 'dropped', dict(dropped))
print(collections.Counter(r[5] for r in rows))
print('no_code', sum('no_code' in r[7] for r in rows), 'dup_code', sum('dup_code' in r[7] for r in rows), 'disused', sum('disused' in r[7] for r in rows))
