#!/usr/bin/env python3
"""Pasang/perbarui navbar kapsul bersama di semua halaman landing page.

Markup navbar ditulis di satu tempat (fungsi navbar() di bawah), lalu disisipkan
ke tiap halaman di antara <!--TKN:MULAI--> dan <!--TKN:SELESAI-->. Saat pertama
dijalankan, header lama halaman diganti. Jalankan ulang setelah mengubah menu:

    python3 scripts/landing_navbar.py
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "landing_page"
CSS = '<link rel="stylesheet" href="/assets/css/tk-navbar.css?v=2">'
JS = '<script src="/assets/js/tk-navbar.js?v=1" defer></script>'

# halaman -> (tautan aktif, perlu spacer di bawah navbar)
PAGES = {
    "index.html": ("/", False),
    "jadwal/index.html": ("/jadwal/", False),
    "cctv/index.html": ("/cctv/", True),
    "artikel/index.html": ("/artikel/", True),
    "artikel/apa-itu-teman-kereta/index.html": ("/artikel/", True),
    "artikel/aplikasi-alarm-turun-stasiun-krl/index.html": ("/artikel/", True),
    "artikel/cek-posisi-dan-jadwal-krl-commuter-line/index.html": ("/artikel/", True),
    "artikel/notifikasi-krl-commuter-line/index.html": ("/artikel/", True),
    "artikel/tips-tidak-kebablasan-stasiun-krl/index.html": ("/artikel/", True),
    "tentang/index.html": ("/tentang/", True),
    "privacy.html": (None, True),
    "terms.html": (None, True),
    "delete-account.html": (None, True),
    "forum.html": ("/forum", True),
}

DESKTOP = [("/", "Beranda"), ("/#fitur", "Fitur"), ("/#cara-kerja", "Cara Kerja"),
           ("/jadwal/", "Jadwal"), ("/cctv/", "CCTV Stasiun"), ("/artikel/", "Artikel")]
MOBILE = [("/", "Beranda"), ("/forum", "Forum Komunitas KRL"), ("/#fitur", "Fitur"),
          ("/#cara-kerja", "Cara Kerja"), ("/#faq", "FAQ"), ("/jadwal/", "Jadwal KRL"),
          ("/cctv/", "CCTV Stasiun"), ("/artikel/", "Artikel"), ("/tentang/", "Tentang")]

DL = ('<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" '
      'stroke-linejoin="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>'
      '<path d="m7 10 5 5 5-5"/><path d="M12 15V3"/></svg>')


def link(href, label, active, cls=""):
    cur = ' aria-current="page"' if href == active else ""
    live = '<span class="tkn-live" aria-hidden="true"></span>' if href == "/cctv/" else ""
    c = f' class="{cls}"' if cls else ""
    return f'<a href="{href}"{c}{cur}>{live}{label}</a>'


def navbar(active):
    d = "\n        ".join(link(h, l, active) for h, l in DESKTOP)
    m = "\n      ".join(link(h, l, active) for h, l in MOBILE)
    return f'''<!--TKN:MULAI-->
  <header class="tkn">
    <div class="tkn-bar">
      <a href="/" class="tkn-brand" aria-label="Teman Kereta, ke beranda">
        <span class="tkn-logo"><img src="/assets/branding/tk_icon.png" alt="" width="36" height="36"></span>
        <span class="tkn-name"><b>Teman Kereta</b><small>Teman Perjalanan KRL</small></span>
      </a>
      <nav class="tkn-nav" aria-label="Navigasi utama">
        {d}
      </nav>
      <div class="tkn-end">
        <a href="/#unduh" class="tkn-cta">{DL}<span>Unduh Aplikasi</span></a>
      </div>
      <button type="button" id="tkn-burger" class="tkn-burger" aria-label="Buka menu" aria-expanded="false" aria-controls="tkn-menu">
        <svg class="tkn-lines" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h16"/></svg>
        <svg class="tkn-x" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18"/></svg>
      </button>
    </div>
    <nav id="tkn-menu" class="tkn-menu" aria-label="Navigasi utama" hidden>
      {m}
      <a href="/#unduh" class="tkn-cta">{DL}<span>Unduh di Google Play</span></a>
    </nav>
  </header>
  <!--TKN:SELESAI-->'''


def svg_filter():
    src = (ROOT / "index.html").read_text(encoding="utf-8")
    m = re.search(r"  <!-- Liquid glass: pembiasan tepi.*?</defs></svg>\n", src, re.S)
    assert m, "filter SVG tk-lg tidak ditemukan di index.html"
    return m.group(0)


def main():
    filt = svg_filter()
    for rel, (active, spacer) in PAGES.items():
        p = ROOT / rel
        s = p.read_text(encoding="utf-8")
        block = navbar(active) + ('\n  <div class="tkn-space" aria-hidden="true"></div>' if spacer else "")
        if "<!--TKN:MULAI-->" in s:
            s = re.sub(r"<!--TKN:MULAI-->.*?<!--TKN:SELESAI-->(\n  <div class=\"tkn-space\" aria-hidden=\"true\"></div>)?",
                       lambda _: block, s, count=1, flags=re.S)
        elif rel == "index.html":
            s = re.sub(r"  <header class=\"tk-glass-nav.*?</header>", lambda _: "  " + block, s, count=1, flags=re.S)
        elif rel == "forum.html":
            # Bar forum (cari + akun) tetap; kapsul ditaruh di atasnya.
            s = s.replace('<header class="sticky top-0 z-40', '<header class="sticky top-[76px] sm:top-[92px] z-40', 1)
            s = re.sub(r"(<body[^>]*>)", lambda m: m.group(1) + "\n  " + block, s, count=1)
        else:
            s, n = re.subn(r"  <header class=\"lg-header\">.*?</header>", lambda _: "  " + block, s, count=1, flags=re.S)
            assert n == 1, rel
        if 'id="tk-lg"' not in s:
            s = re.sub(r"(<body[^>]*>\n)", lambda m: m.group(1) + filt, s, count=1)
        if CSS not in s:
            s = s.replace("</head>", "  " + CSS + "\n</head>", 1)
        if JS not in s:
            s = s.replace("</body>", "  " + JS + "\n</body>", 1)
        p.write_text(s, encoding="utf-8")
        print("ok", rel)


if __name__ == "__main__":
    main()
