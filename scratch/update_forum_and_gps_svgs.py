import os

screenshots_dir = r"c:\Projet\Teman Kereta\landing_page\assets\screenshots"

# 1. Screen Tracking SVG (GPS Live Penumpang Anonim)
tracking_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 780" width="380" height="780" style="background:#090d16; font-family:'Plus Jakarta Sans', -apple-system, system-ui, sans-serif;">
  <defs>
    <linearGradient id="surfaceGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#151d2f"/>
      <stop offset="100%" stop-color="#0f172a"/>
    </linearGradient>
  </defs>
  
  <!-- Header -->
  <rect width="380" height="85" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
  <text x="24" y="52" fill="#f8fafc" font-size="17" font-weight="700">Posisi GPS Live Penumpang</text>
  
  <!-- Map Route Area -->
  <rect x="16" y="100" width="348" height="280" rx="20" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
  
  <!-- Route Path -->
  <path d="M 50 160 Q 180 130 310 230 T 190 330" fill="none" stroke="#ef4444" stroke-width="5" stroke-linecap="round"/>
  
  <circle cx="50" cy="160" r="6" fill="#ffffff" stroke="#ef4444" stroke-width="2.5"/>
  <text x="45" y="140" fill="#cbd5e1" font-size="11" font-weight="600">Jakarta Kota</text>

  <circle cx="180" cy="175" r="6" fill="#ffffff" stroke="#ef4444" stroke-width="2.5"/>
  <text x="170" y="158" fill="#cbd5e1" font-size="11" font-weight="600">Manggarai</text>

  <!-- Live Aggregated Position Pin Indicator -->
  <g transform="translate(140, 155)">
    <circle cx="14" cy="14" r="14" fill="#2563eb" stroke="#ffffff" stroke-width="2"/>
    <circle cx="14" cy="14" r="4" fill="#ffffff"/>
  </g>

  <circle cx="310" cy="230" r="6" fill="#ffffff" stroke="#ef4444" stroke-width="2.5"/>
  <text x="300" y="255" fill="#cbd5e1" font-size="11" font-weight="600">Depok</text>

  <circle cx="190" cy="330" r="6" fill="#ffffff" stroke="#ef4444" stroke-width="2.5"/>
  <text x="180" y="355" fill="#cbd5e1" font-size="11" font-weight="600">Bogor</text>

  <!-- Live Tracking Detail (GPS Anonim) -->
  <g transform="translate(16, 400)">
    <rect width="348" height="150" rx="18" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <rect x="20" y="20" width="135" height="22" rx="6" fill="#2563eb" fill-opacity="0.15"/>
    <text x="28" y="35" fill="#60a5fa" font-size="10" font-weight="700" letter-spacing="0.5">GPS PENUMPANG LIVE</text>
    
    <text x="20" y="70" fill="#ffffff" font-size="17" font-weight="800">KA 1182 • Bogor Line</text>
    <text x="20" y="94" fill="#94a3b8" font-size="12">Posisi Terkini: <tspan fill="#34d399" font-weight="600">Mendekati Tebet</tspan></text>
    <text x="20" y="116" fill="#94a3b8" font-size="12">Privasi: <tspan fill="#60a5fa" font-weight="600">Anonim &amp; Terenkripsi</tspan></text>
    
    <rect x="20" y="132" width="308" height="6" rx="3" fill="#1e293b"/>
    <rect x="20" y="132" width="220" height="6" rx="3" fill="#2563eb"/>
  </g>

  <!-- Privacy Notice Banner -->
  <g transform="translate(16, 568)">
    <rect width="348" height="180" rx="18" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <text x="20" y="28" fill="#ffffff" font-size="14" font-weight="700">Jaminan Privasi Pengguna</text>
    
    <circle cx="28" cy="60" r="4.5" fill="#10b981"/>
    <text x="44" y="64" fill="#e2e8f0" font-size="12" font-weight="600">Posisi Orang Lain Tidak Terlihat</text>
    <text x="44" y="80" fill="#94a3b8" font-size="11">Data hanya digunakan untuk menghitung pergerakan kereta.</text>
    
    <circle cx="28" cy="115" r="4.5" fill="#3b82f6"/>
    <text x="44" y="119" fill="#e2e8f0" font-size="12" font-weight="600">Pemrosesan Lokal di Perangkat</text>
    <text x="44" y="135" fill="#94a3b8" font-size="11">GPS otomatis nonaktif saat Anda tidak bepergian.</text>
  </g>
</svg>"""

with open(os.path.join(screenshots_dir, "screen-tracking.svg"), "w", encoding="utf-8") as f:
  f.write(tracking_svg)

# 2. Screen Crowd SVG (Forum Komunitas)
crowd_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 780" width="380" height="780" style="background:#090d16; font-family:'Plus Jakarta Sans', -apple-system, system-ui, sans-serif;">
  <defs>
    <linearGradient id="surfaceGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#151d2f"/>
      <stop offset="100%" stop-color="#0f172a"/>
    </linearGradient>
  </defs>

  <rect width="380" height="85" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
  <text x="24" y="52" fill="#f8fafc" font-size="17" font-weight="700">Forum Kepadatan &amp; Info Kereta</text>

  <!-- Forum Header -->
  <g transform="translate(20, 105)">
    <rect width="340" height="74" rx="16" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <text x="20" y="32" fill="#ffffff" font-size="14.5" font-weight="700">Diskusi Jalur Bogor &amp; Cikarang</text>
    <text x="20" y="52" fill="#94a3b8" font-size="11.5">Aktivitas Terbaru: <tspan fill="#34d399" font-weight="600">Baru saja</tspan></text>
  </g>

  <!-- Forum Thread Posts -->
  <g transform="translate(20, 195)">
    <rect width="340" height="250" rx="20" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <text x="20" y="28" fill="#ffffff" font-size="13.5" font-weight="700">Kabar Terkini dari Penumpang</text>
    
    <!-- Post 1 -->
    <rect x="20" y="44" width="300" height="60" rx="12" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <circle cx="36" cy="64" r="8" fill="#2563eb"/>
    <text x="52" y="60" fill="#94a3b8" font-size="10.5">Pengguna KA 1184 • 2 mnt lalu</text>
    <text x="52" y="76" fill="#e2e8f0" font-size="11.5" font-weight="600">Gerbong 4 &amp; 5 masih cukup lengang</text>

    <!-- Post 2 -->
    <rect x="20" y="112" width="300" height="60" rx="12" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <circle cx="36" cy="132" r="8" fill="#f59e0b"/>
    <text x="52" y="128" fill="#94a3b8" font-size="10.5">Stasiun Manggarai • 5 mnt lalu</text>
    <text x="52" y="144" fill="#e2e8f0" font-size="11.5" font-weight="600">Peron 11 ramai, lift beroperasi normal</text>

    <!-- Post 3 -->
    <rect x="20" y="180" width="300" height="54" rx="12" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <circle cx="36" cy="200" r="8" fill="#10b981"/>
    <text x="52" y="196" fill="#94a3b8" font-size="10.5">Jalur Tanah Abang • 8 mnt lalu</text>
    <text x="52" y="212" fill="#e2e8f0" font-size="11.5" font-weight="600">Kereta arah Rangkas tepat waktu</text>
  </g>

  <!-- Join Discussion CTA -->
  <g transform="translate(20, 460)">
    <rect width="340" height="235" rx="20" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <text x="20" y="30" fill="#ffffff" font-size="13.5" font-weight="700">Tanya atau Berbagi Info</text>
    <text x="20" y="50" fill="#94a3b8" font-size="11.5">Tanyakan kondisi peron atau bagikan info gerbongmu:</text>

    <rect x="20" y="70" width="300" height="80" rx="12" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <text x="32" y="96" fill="#64748b" font-size="11.5">Tulis pesan atau info kondisi gerbong...</text>

    <rect x="20" y="165" width="300" height="42" rx="12" fill="#2563eb"/>
    <text x="170" y="191" text-anchor="middle" fill="#ffffff" font-size="12.5" font-weight="700">Kirim ke Forum</text>
  </g>
</svg>"""

with open(os.path.join(screenshots_dir, "screen-crowd.svg"), "w", encoding="utf-8") as f:
  f.write(crowd_svg)

print("Updated tracking and crowd SVG files!")
