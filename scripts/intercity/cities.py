import json, sys, time, urllib.request, urllib.parse
S = sys.argv[1]
used = json.load(open(f'{S}/used_stations.json', encoding='utf-8'))
out = {}
UA = {'User-Agent': 'TemanKereta-city-lookup/1.0 (aziz@skor.co)'}
for i, s in enumerate(used):
    q = urllib.parse.urlencode({'lat': s['lat'], 'lon': s['lon'], 'format': 'jsonv2', 'zoom': 10, 'accept-language': 'id', 'addressdetails': 1})
    r = None
    for t in range(3):
        try:
            r = json.load(urllib.request.urlopen(urllib.request.Request('https://nominatim.openstreetmap.org/reverse?' + q, headers=UA), timeout=30))
            break
        except Exception:
            time.sleep(3)
    a = (r or {}).get('address', {})
    city = a.get('city') or a.get('town') or a.get('county') or a.get('municipality') or a.get('regency') or a.get('state_district') or a.get('village') or ''
    out[s['code']] = {'city': city, 'state': a.get('state', ''), 'raw': {k: a.get(k) for k in ('city', 'town', 'county', 'municipality', 'state_district', 'state') if a.get(k)}}
    if i % 20 == 0:
        print(i, s['name'], '->', city, '/', a.get('state', ''), flush=True)
    time.sleep(1.2)
json.dump(out, open(f'{S}/station_cities.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('done', len(out))
