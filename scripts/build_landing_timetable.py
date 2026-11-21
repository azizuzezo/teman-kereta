#!/usr/bin/env python3
"""Bangun data timetable untuk landing page (/jadwal/) dari feed GAPEKA 2026.

Sumber : supabase/data/gapeka-2026/import/{krl-jabodetabek,krl-yogyakarta,gapeka-kci,gapeka-kai}
Keluar : landing_page/jadwal/data.json (dimuat browser)
         ringkasan per lintas, disisipkan ke landing_page/jadwal/index.html
         di antara penanda <!--RINGKASAN:MULAI--> dan <!--RINGKASAN:SELESAI-->

Tidak menyentuh database. Jalankan ulang bila feed berubah:
    python3 scripts/build_landing_timetable.py
"""
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FEEDS = ROOT / "supabase/data/gapeka-2026/import"
OUT = ROOT / "landing_page/jadwal"

SOURCES = ["krl-jabodetabek", "krl-yogyakarta", "gapeka-kci", "gapeka-kai"]
GROUP = {
    "krl-jabodetabek": "KRL Jabodetabek",
    "krl-yogyakarta": "KRL Yogyakarta",
    "gapeka-kci": "Commuter Line lain (KCI)",
    "gapeka-kai": "KA lokal (KAI)",
}
# Nama tampil lintas. Kode feed dipertahankan sebagai id.
LINE_LABEL = {
    "BOGOR": "Bogor / Nambo",
    "CIKARANG": "Cikarang (Loop)",
    "RANGKASBITUNG": "Rangkasbitung",
    "TANGERANG": "Tangerang",
    "TANJUNG_PRIOK": "Tanjung Priok",
    "YKPL": "Yogyakarta - Palur",
}


def rows(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def minutes(hhmmss):
    h, m, _ = hhmmss.split(":")
    return int(h) * 60 + int(m)


def hhmm(total):
    return "%02d:%02d" % ((total // 60) % 24, total % 60)


def main():
    stations = {}  # id -> nama
    lines = {}  # id -> dict
    trips = []  # (line, no, head, fak, [(stop, menit, est)])

    for src in SOURCES:
        d = FEEDS / src
        for r in rows(d / "stops.txt"):
            stations[r["stop_id"]] = r["stop_name"]
        for r in rows(d / "routes.txt"):
            lines[r["route_id"]] = {
                "id": r["route_id"],
                "name": LINE_LABEL.get(r["route_id"], r["route_short_name"]),
                "long": r["route_long_name"],
                "group": GROUP[src],
                "color": r["route_color"] or None,
            }
        st = {}
        for r in rows(d / "stop_times.txt"):
            st.setdefault(r["trip_id"], []).append(r)
        for t in rows(d / "trips.txt"):
            seq = sorted(st[t["trip_id"]], key=lambda x: int(x["stop_sequence"]))
            stops = []
            for s in seq:
                # keberangkatan; stasiun akhir hanya punya jam tiba
                stops.append((s["stop_id"], minutes(s["departure_time"] or s["arrival_time"]),
                              0 if s["timepoint"] == "1" else 1))
            trips.append((t["route_id"], t["trip_short_name"], t["trip_headsign"],
                          1 if "FAKULTATIF" in t["service_id"] else 0, stops))

    used = sorted({s for t in trips for s, _, _ in t[4]})
    idx = {s: i for i, s in enumerate(used)}
    unknown = [s for s in used if s not in stations]
    assert not unknown, "stasiun tanpa nama: %s" % unknown

    out_lines = []
    for lid, meta in lines.items():
        lt = [t for t in trips if t[0] == lid]
        lt.sort(key=lambda t: t[4][0][1])
        meta = dict(meta)
        meta["trips"] = [[
            t[1], t[2], t[3],
            [idx[s] for s, _, _ in t[4]],
            [m for _, m, _ in t[4]],
            "".join(str(e) for _, _, e in t[4]),
        ] for t in lt]
        out_lines.append(meta)

    data = {
        "versi": "GAPEKA 2026",
        "berlaku": "2026-12-01",
        "stations": [[s, stations[s]] for s in used],
        "lines": out_lines,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "data.json").write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")),
                                   encoding="utf-8")

    # Ringkasan statis (terbaca tanpa JavaScript, dan oleh mesin pencari)
    tr = []
    total = 0
    for l in out_lines:
        n = len(l["trips"])
        total += n
        firsts = [t[4][0] for t in l["trips"]]
        lasts = [t[4][-1] for t in l["trips"]]
        stn = len({i for t in l["trips"] for i in t[3]})
        tr.append(
            "<tr><th scope=\"row\">%s</th><td>%d</td><td>%d</td><td>%s</td><td>%s</td></tr>"
            % (l["name"], n, stn, hhmm(min(firsts)), hhmm(max(lasts))))
    summary = (
        "<table class=\"jd-sum\"><caption>Ringkasan GAPEKA 2026 per lintas</caption>"
        "<thead><tr><th scope=\"col\">Lintas</th><th scope=\"col\">Perjalanan</th>"
        "<th scope=\"col\">Stasiun</th><th scope=\"col\">Berangkat pertama</th>"
        "<th scope=\"col\">Tiba terakhir</th></tr></thead><tbody>"
        + "".join(tr) + "</tbody></table>")
    page = OUT / "index.html"
    if page.exists():
        html = page.read_text(encoding="utf-8")
        html = re.sub(r"<!--RINGKASAN:MULAI-->.*?<!--RINGKASAN:SELESAI-->",
                      lambda m: "<!--RINGKASAN:MULAI-->" + summary + "<!--RINGKASAN:SELESAI-->",
                      html, flags=re.S)
        page.write_text(html, encoding="utf-8")

    size = (OUT / "data.json").stat().st_size
    print("lintas=%d perjalanan=%d stasiun=%d data.json=%d KB" %
          (len(out_lines), total, len(used), size // 1024))


if __name__ == "__main__":
    main()
