import json, re, sys, collections
S = sys.argv[1]
w = json.load(open(f'{S}/wp_Daftar_kereta_api_di_Indonesia.json', encoding='utf-8'))['parse']['wikitext']

def strip_templates(s):
    # {{sta|A|3=B}} -> A ; {{KA|X}} -> X ; {{abbr|a|b}} -> a ; {{cslist|..}} -> inner ; other {{..}} dropped
    prev = None
    while prev != s:
        prev = s
        s = re.sub(r'\{\{\s*(?:sta|Sta)\s*\|([^{}|]*)(?:\|[^{}]*)?\}\}', r'\1', s)
        s = re.sub(r'\{\{\s*(?:KA|kereta api|Kereta api)\s*\|([^{}|]*)(?:\|[^{}]*)?\}\}', r'\1', s)
        s = re.sub(r'\{\{\s*abbr\s*\|([^{}|]*)(?:\|[^{}]*)?\}\}', r'\1', s)
        s = re.sub(r'\{\{\s*cslist\s*\|([^{}]*)\}\}', r'\1', s)
        s = re.sub(r'\{\{\s*efn[^{}]*\}\}', '', s)
    s = re.sub(r'\{\{[^{}]*\}\}', '', s)
    s = re.sub(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]', r'\1', s)
    s = re.sub(r"'''?", '', s)
    s = re.sub(r'<ref[^>]*>.*?</ref>|<ref[^>]*/>', '', s, flags=re.S)
    s = re.sub(r'<br\s*/?>', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()

def parse_tables(text):
    """yield (heading_path, header_cells, rows) with rowspan-aware cells"""
    heads = []; out = []
    lines = text.split('\n'); i = 0
    while i < len(lines):
        ln = lines[i]
        m = re.match(r'^(=+)\s*(.*?)\s*\1\s*$', ln)
        if m:
            lvl = len(m.group(1)); heads = heads[:lvl - 2] + [strip_templates(m.group(2))] if lvl >= 2 else heads
            i += 1; continue
        if ln.startswith('{|'):
            j = i; rows = []; cur = []; header = None
            while not lines[j].startswith('|}'):
                l = lines[j]
                if l.startswith('|-'):
                    if cur: rows.append(cur)
                    cur = []
                elif l.startswith('!') or l.startswith('|'):
                    isth = l.startswith('!')
                    body = l[1:]
                    # split multiple cells on '||'
                    for cell in re.split(r'\|\||!!', body):
                        attrs = ''
                        if '|' in cell and not cell.lstrip().startswith('{{') and '[[' not in cell.split('|')[0] and '{{' not in cell.split('|')[0]:
                            attrs, cell = cell.split('|', 1)
                        rs = re.search(r'rowspan="?(\d+)', attrs); cs = re.search(r'colspan="?(\d+)', attrs)
                        cur.append({'th': isth, 'raw': cell.strip(), 'rs': int(rs.group(1)) if rs else 1, 'cs': int(cs.group(1)) if cs else 1})
                elif cur and l.strip() and not l.startswith(('{|', '|+')):
                    cur[-1]['raw'] += '\n' + l
                j += 1
            if cur: rows.append(cur)
            out.append((list(heads), rows)); i = j
        i += 1
    return out

def expand(rows, ncols=5):
    grid = []; pend = {}
    for r in rows:
        row = []; c = 0; it = iter(r)
        cells = list(r); k = 0
        while c < ncols:
            if c in pend and pend[c][1] > 0:
                row.append(pend[c][0]); pend[c][1] -= 1; c += 1; continue
            if k >= len(cells): break
            cell = cells[k]; k += 1
            if cell['th'] and cell['cs'] >= ncols: row = [cell]; c = ncols; break
            for x in range(cell['cs']):
                row.append(cell['raw']);
                if cell['rs'] > 1: pend[c] = [cell['raw'], cell['rs'] - 1]
                c += 1
        grid.append(row)
    return grid

services = []
for heads, rows in parse_tables(w):
    ncols = 5
    for r in rows:
        if r and r[0]['th'] and r[0]['raw'].strip().startswith('Nama'):
            ncols = len(r); break
    for g in expand(rows, ncols):
        if ncols == 4 and len(g) == 4: g = [g[0], 'Ekonomi', g[1], g[2], g[3]]
        if len(g) < 5 or g[0].lstrip().startswith(('Nama',)): continue
        name = strip_templates(g[0]); kelas = strip_templates(g[1]); rel = strip_templates(g[2]); freq = strip_templates(g[3]); stops = strip_templates(g[4])
        if not name or name in ('Nama',) or 'wikitable' in name: continue
        services.append({'section': ' > '.join(h for h in heads if h), 'name': name, 'class': kelas, 'relation': rel, 'freq': freq, 'stops_raw': stops, 'stops_wikitext': g[4]})
print(len(services))
json.dump(services, open(f'{S}/ka_services_raw.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
names = collections.Counter(s['name'] for s in services)
print('distinct names', len(names))
for s in services[:6]: print(s['section'], '|', s['name'], '|', s['class'], '|', s['relation'], '|', s['stops_raw'][:90])
print(collections.Counter(s['section'].split(' > ')[0] if s['section'] else '' for s in services))
