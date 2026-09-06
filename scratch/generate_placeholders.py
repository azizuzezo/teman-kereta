import os

screenshots_dir = r"c:\Projet\Teman Kereta\landing_page\assets\screenshots"
os.makedirs(screenshots_dir, exist_ok=True)

# 1. Hero Preview SVG
hero_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 780" width="380" height="780" style="background:#0b1329; font-family:'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;">
  <defs>
    <linearGradient id="blueGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2563eb"/>
      <stop offset="100%" stop-color="#1d4ed8"/>
    </linearGradient>
    <linearGradient id="cardGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#1e293b"/>
      <stop offset="100%" stop-color="#0f172a"/>
    </linearGradient>
    <linearGradient id="redGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ef4444"/>
      <stop offset="100%" stop-color="#dc2626"/>
    </linearGradient>
  </defs>

  <!-- Status Bar -->
  <text x="32" y="32" fill="#94a3b8" font-size="12" font-weight="600">07:42</text>
  <circle cx="330" cy="28" r="4" fill="#94a3b8"/>
  <circle cx="342" cy="28" r="4" fill="#94a3b8"/>
  <rect x="352" y="24" width="16" height="8" rx="2" fill="#94a3b8"/>

  <!-- App Header -->
  <g transform="translate(24, 52)">
    <circle cx="20" cy="20" r="20" fill="url(#blueGrad)"/>
    <path d="M12 20 L28 20 M20 12 L20 28" stroke="#ffffff" stroke-width="2.5" stroke-linecap="round"/>
    <text x="50" y="16" fill="#94a3b8" font-size="11" font-weight="500">Selamat Pagi,</text>
    <text x="50" y="32" fill="#ffffff" font-size="16" font-weight="700">Pejuang Commuter 👋</text>
  </g>

  <!-- Active Journey Banner -->
  <g transform="translate(20, 110)">
    <rect width="340" height="170" rx="20" fill="url(#blueGrad)"/>
    
    <!-- Top badge -->
    <rect x="16" y="14" width="110" height="24" rx="12" fill="#ffffff" fill-opacity="0.2"/>
    <circle cx="28" cy="26" r="4" fill="#4ade80"/>
    <text x="38" y="30" fill="#ffffff" font-size="11" font-weight="600">LIVE TRACKING</text>
    
    <text x="240" y="30" fill="#ffffff" fill-opacity="0.8" font-size="11">KA 1154 • Cikarang</text>
    
    <!-- Stations & Line -->
    <text x="16" y="70" fill="#ffffff" font-size="20" font-weight="800">Manggarai</text>
    <text x="16" y="88" fill="#bfdbfe" font-size="12">Peron 11 / 12 • Menuju Cikarang</text>
    
    <!-- Progress Line -->
    <line x1="16" y1="112" x2="324" y2="112" stroke="#60a5fa" stroke-width="4" stroke-linecap="round"/>
    <circle cx="90" cy="112" r="7" fill="#ffffff" stroke="#2563eb" stroke-width="3"/>
    <circle cx="16" cy="112" r="4" fill="#ffffff"/>
    <circle cx="324" cy="112" r="4" fill="#ffffff"/>
    
    <text x="16" y="132" fill="#dbeafe" font-size="10">Tanah Abang</text>
    <text x="80" y="145" fill="#facc15" font-weight="700" font-size="11">Posisi Kereta (2 mnt)</text>
    <text x="280" y="132" fill="#dbeafe" font-size="10">Cikarang</text>
    
    <!-- Bottom row -->
    <rect x="16" y="128" width="150" height="26" rx="6" fill="#000000" fill-opacity="0.2"/>
    <text x="26" y="145" fill="#ffffff" font-size="11" font-weight="600">🔔 Pengingat Aktif (Tebet)</text>
  </g>

  <!-- Quick Menu -->
  <g transform="translate(20, 298)">
    <rect x="0" y="0" width="76" height="74" rx="16" fill="url(#cardGrad)" stroke="#334155" stroke-width="1"/>
    <circle cx="38" cy="28" r="14" fill="#3b82f6" fill-opacity="0.2"/>
    <text x="38" y="32" text-anchor="middle" fill="#60a5fa" font-size="14">🗺️</text>
    <text x="38" y="58" text-anchor="middle" fill="#cbd5e1" font-size="10" font-weight="600">Rute Pintar</text>

    <rect x="88" y="0" width="76" height="74" rx="16" fill="url(#cardGrad)" stroke="#334155" stroke-width="1"/>
    <circle cx="126" cy="28" r="14" fill="#f59e0b" fill-opacity="0.2"/>
    <text x="126" y="32" text-anchor="middle" fill="#fbbf24" font-size="14">⏱️</text>
    <text x="126" y="58" text-anchor="middle" fill="#cbd5e1" font-size="10" font-weight="600">Jadwal Live</text>

    <rect x="176" y="0" width="76" height="74" rx="16" fill="url(#cardGrad)" stroke="#334155" stroke-width="1"/>
    <circle cx="214" cy="28" r="14" fill="#10b981" fill-opacity="0.2"/>
    <text x="214" y="32" text-anchor="middle" fill="#34d399" font-size="14">👥</text>
    <text x="214" y="58" text-anchor="middle" fill="#cbd5e1" font-size="10" font-weight="600">Kepadatan</text>

    <rect x="264" y="0" width="76" height="74" rx="16" fill="url(#cardGrad)" stroke="#334155" stroke-width="1"/>
    <circle cx="302" cy="28" r="14" fill="#a855f7" fill-opacity="0.2"/>
    <text x="302" y="32" text-anchor="middle" fill="#c084fc" font-size="14">🏢</text>
    <text x="302" y="58" text-anchor="middle" fill="#cbd5e1" font-size="10" font-weight="600">Stasiun</text>
  </g>

  <!-- Section Title -->
  <text x="24" y="405" fill="#ffffff" font-size="15" font-weight="700">Keberangkatan Berikutnya</text>
  <text x="290" y="405" fill="#60a5fa" font-size="12" font-weight="600">Lihat Semua</text>

  <!-- Schedule Card 1 -->
  <g transform="translate(20, 420)">
    <rect width="340" height="76" rx="16" fill="url(#cardGrad)" stroke="#1e293b" stroke-width="1"/>
    <rect x="16" y="16" width="6" height="44" rx="3" fill="#ef4444"/>
    <text x="32" y="34" fill="#ffffff" font-size="14" font-weight="700">Bogor (Line Merah)</text>
    <text x="32" y="52" fill="#94a3b8" font-size="11">KA 1188 • Via Pasar Minggu</text>
    <rect x="245" y="16" width="78" height="28" rx="8" fill="#ef4444" fill-opacity="0.2"/>
    <text x="284" y="34" text-anchor="middle" fill="#f87171" font-size="12" font-weight="700">07:48 (6m)</text>
    <text x="284" y="54" text-anchor="middle" fill="#4ade80" font-size="10">🟢 Lengang</text>
  </g>

  <!-- Schedule Card 2 -->
  <g transform="translate(20, 508)">
    <rect width="340" height="76" rx="16" fill="url(#cardGrad)" stroke="#1e293b" stroke-width="1"/>
    <rect x="16" y="16" width="6" height="44" rx="3" fill="#3b82f6"/>
    <text x="32" y="34" fill="#ffffff" font-size="14" font-weight="700">Cikarang (Line Biru)</text>
    <text x="32" y="52" fill="#94a3b8" font-size="11">KA 1204 • Via Jatinegara</text>
    <rect x="245" y="16" width="78" height="28" rx="8" fill="#3b82f6" fill-opacity="0.2"/>
    <text x="284" y="34" text-anchor="middle" fill="#60a5fa" font-size="12" font-weight="700">07:54 (12m)</text>
    <text x="284" y="54" text-anchor="middle" fill="#facc15" font-size="10">🟡 Sedang</text>
  </g>

  <!-- Schedule Card 3 -->
  <g transform="translate(20, 596)">
    <rect width="340" height="76" rx="16" fill="url(#cardGrad)" stroke="#1e293b" stroke-width="1"/>
    <rect x="16" y="16" width="6" height="44" rx="3" fill="#10b981"/>
    <text x="32" y="34" fill="#ffffff" font-size="14" font-weight="700">Rangkasbitung (Hijau)</text>
    <text x="32" y="52" fill="#94a3b8" font-size="11">KA 2042 • Via Serpong</text>
    <rect x="245" y="16" width="78" height="28" rx="8" fill="#10b981" fill-opacity="0.2"/>
    <text x="284" y="34" text-anchor="middle" fill="#34d399" font-size="12" font-weight="700">08:02 (20m)</text>
    <text x="284" y="54" text-anchor="middle" fill="#f87171" font-size="10">🔴 Padat</text>
  </g>

  <!-- Bottom Nav Bar -->
  <g transform="translate(0, 695)">
    <rect width="380" height="85" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <text x="50" y="740" text-anchor="middle" fill="#3b82f6" font-size="18">🏠</text>
    <text x="50" y="756" text-anchor="middle" fill="#3b82f6" font-size="9" font-weight="700">Beranda</text>

    <text x="140" y="740" text-anchor="middle" fill="#64748b" font-size="18">🗺️</text>
    <text x="140" y="756" text-anchor="middle" fill="#64748b" font-size="9">Rute</text>

    <text x="240" y="740" text-anchor="middle" fill="#64748b" font-size="18">🔔</text>
    <text x="240" y="756" text-anchor="middle" fill="#64748b" font-size="9">Alarm</text>

    <text x="330" y="740" text-anchor="middle" fill="#64748b" font-size="18">⚙️</text>
    <text x="330" y="756" text-anchor="middle" fill="#64748b" font-size="9">Akun</text>
  </g>
</svg>"""

with open(os.path.join(screenshots_dir, "hero-preview.svg"), "w", encoding="utf-8") as f:
  f.write(hero_svg)

# 2. Real-time Tracking Screen SVG
tracking_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 780" width="380" height="780" style="background:#0f172a; font-family:'Plus Jakarta Sans', system-ui, sans-serif;">
  <defs>
    <linearGradient id="trBlue" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#3b82f6"/>
      <stop offset="100%" stop-color="#1d4ed8"/>
    </linearGradient>
  </defs>
  <!-- Header -->
  <rect width="380" height="85" fill="#1e293b"/>
  <text x="24" y="52" fill="#ffffff" font-size="18" font-weight="700">📍 Posisi &amp; Live Tracking</text>
  
  <!-- Map Simulation Area -->
  <rect x="16" y="100" width="348" height="280" rx="20" fill="#1e293b" stroke="#334155" stroke-width="1"/>
  <path d="M 50 160 Q 180 130 310 230 T 190 330" fill="none" stroke="#ef4444" stroke-width="6" stroke-linecap="round"/>
  <circle cx="50" cy="160" r="8" fill="#ffffff" stroke="#ef4444" stroke-width="3"/>
  <text x="45" y="140" fill="#ffffff" font-size="11" font-weight="600">Jakarta Kota</text>

  <circle cx="180" cy="175" r="8" fill="#ffffff" stroke="#ef4444" stroke-width="3"/>
  <text x="170" y="160" fill="#ffffff" font-size="11" font-weight="600">Manggarai</text>

  <!-- Moving Train Icon -->
  <g transform="translate(140, 155)">
    <circle cx="16" cy="16" r="16" fill="#2563eb" stroke="#ffffff" stroke-width="2"/>
    <text x="16" y="21" text-anchor="middle" fill="#ffffff" font-size="12">🚆</text>
  </g>

  <circle cx="310" cy="230" r="8" fill="#ffffff" stroke="#ef4444" stroke-width="3"/>
  <text x="300" y="255" fill="#ffffff" font-size="11" font-weight="600">Depok</text>

  <circle cx="190" cy="330" r="8" fill="#ffffff" stroke="#ef4444" stroke-width="3"/>
  <text x="180" y="355" fill="#ffffff" font-size="11" font-weight="600">Bogor</text>

  <!-- Live Status Card -->
  <g transform="translate(16, 400)">
    <rect width="348" height="150" rx="16" fill="#1e293b" stroke="#334155" stroke-width="1"/>
    <text x="20" y="35" fill="#38bdf8" font-size="12" font-weight="700">KERETA AKTIF</text>
    <text x="20" y="60" fill="#ffffff" font-size="18" font-weight="800">KA 1182 (Bogor Line)</text>
    <text x="20" y="85" fill="#94a3b8" font-size="12">Stasiun Berikutnya: <tspan fill="#4ade80" font-weight="700">Tebet (1.8 km)</tspan></text>
    <text x="20" y="110" fill="#94a3b8" font-size="12">Estimasi Kedatangan: <tspan fill="#facc15" font-weight="700">07:49 WIB (3 mnt)</tspan></text>
    <rect x="20" y="125" width="308" height="8" rx="4" fill="#334155"/>
    <rect x="20" y="125" width="210" height="8" rx="4" fill="#3b82f6"/>
  </g>

  <!-- Step-by-step route info -->
  <g transform="translate(16, 565)">
    <rect width="348" height="180" rx="16" fill="#1e293b" stroke="#334155" stroke-width="1"/>
    <text x="20" y="30" fill="#ffffff" font-size="14" font-weight="700">Panduan Transit &amp; Peron</text>
    
    <circle cx="30" cy="65" r="5" fill="#3b82f6"/>
    <line x1="30" y1="70" x2="30" y2="120" stroke="#475569" stroke-width="2" stroke-dasharray="3,3"/>
    <text x="45" y="70" fill="#e2e8f0" font-size="12" font-weight="600">Naik Peron 3 (Arah Manggarai)</text>
    
    <circle cx="30" cy="125" r="5" fill="#f59e0b"/>
    <text x="45" y="130" fill="#e2e8f0" font-size="12" font-weight="600">Transit di Stasiun Manggarai</text>
    <text x="45" y="145" fill="#94a3b8" font-size="11">Pindah ke Peron 11 (Arah Bogor)</text>
  </g>
</svg>"""

with open(os.path.join(screenshots_dir, "screen-tracking.svg"), "w", encoding="utf-8") as f:
  f.write(tracking_svg)

# 3. Alarm Screen SVG
alarm_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 780" width="380" height="780" style="background:#0b1329; font-family:'Plus Jakarta Sans', system-ui, sans-serif;">
  <defs>
    <linearGradient id="alarmGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#f59e0b"/>
      <stop offset="100%" stop-color="#d97706"/>
    </linearGradient>
  </defs>

  <rect width="380" height="85" fill="#1e293b"/>
  <text x="24" y="52" fill="#ffffff" font-size="18" font-weight="700">⏰ Alarm Anti-Kelewatan</text>

  <!-- Alarm Active Card Graphic -->
  <g transform="translate(20, 110)">
    <rect width="340" height="280" rx="24" fill="url(#alarmGrad)"/>
    <circle cx="170" cy="70" r="36" fill="#ffffff" fill-opacity="0.2"/>
    <text x="170" y="80" text-anchor="middle" fill="#ffffff" font-size="36">🔔</text>
    <text x="170" y="140" text-anchor="middle" fill="#ffffff" font-size="20" font-weight="800">Bersiap Turun!</text>
    <text x="170" y="168" text-anchor="middle" fill="#fef3c7" font-size="13">Kereta akan tiba di Stasiun tujuan:</text>
    <text x="170" y="200" text-anchor="middle" fill="#ffffff" font-size="22" font-weight="800">Stasiun Tebet</text>
    <text x="170" y="225" text-anchor="middle" fill="#fef3c7" font-size="12">1 Stasiun Lagi • Estimasi 2 Menit</text>
    
    <rect x="40" y="240" width="260" height="28" rx="14" fill="#000000" fill-opacity="0.2"/>
    <text x="170" y="258" text-anchor="middle" fill="#ffffff" font-size="11" font-weight="600">Getar &amp; Suara Sedang Berbunyi 🔊</text>
  </g>

  <!-- Settings Area -->
  <g transform="translate(20, 410)">
    <rect width="340" height="320" rx="20" fill="#1e293b" stroke="#334155" stroke-width="1"/>
    <text x="20" y="35" fill="#ffffff" font-size="15" font-weight="700">Pengaturan Alarm Pintar</text>
    
    <rect x="20" y="55" width="300" height="60" rx="12" fill="#0f172a"/>
    <text x="35" y="80" fill="#ffffff" font-size="13" font-weight="600">Peringatan Sebelum Tujuan</text>
    <text x="35" y="98" fill="#94a3b8" font-size="11">Bunyikan 1 atau 2 stasiun sebelumnya</text>
    <rect x="260" y="72" width="40" height="24" rx="12" fill="#3b82f6"/>
    <circle cx="288" cy="84" r="8" fill="#ffffff"/>

    <rect x="20" y="125" width="300" height="60" rx="12" fill="#0f172a"/>
    <text x="35" y="150" fill="#ffffff" font-size="13" font-weight="600">Peringatan Pindah Jalur / Transit</text>
    <text x="35" y="168" fill="#94a3b8" font-size="11">Alarm saat mendekati stasiun transit</text>
    <rect x="260" y="142" width="40" height="24" rx="12" fill="#3b82f6"/>
    <circle cx="288" cy="154" r="8" fill="#ffffff"/>

    <rect x="20" y="195" width="300" height="60" rx="12" fill="#0f172a"/>
    <text x="35" y="220" fill="#ffffff" font-size="13" font-weight="600">Pola Getar Ekstra Kuat</text>
    <text x="35" y="238" fill="#94a3b8" font-size="11">Cocok saat tidur di gerbong ramai</text>
    <rect x="260" y="212" width="40" height="24" rx="12" fill="#3b82f6"/>
    <circle cx="288" cy="224" r="8" fill="#ffffff"/>
  </g>
</svg>"""

with open(os.path.join(screenshots_dir, "screen-alarm.svg"), "w", encoding="utf-8") as f:
  f.write(alarm_svg)

# 4. Crowd Density Screen SVG
crowd_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 780" width="380" height="780" style="background:#0f172a; font-family:'Plus Jakarta Sans', system-ui, sans-serif;">
  <rect width="380" height="85" fill="#1e293b"/>
  <text x="24" y="52" fill="#ffffff" font-size="18" font-weight="700">👥 Kepadatan Gerbong Real-Time</text>

  <g transform="translate(20, 105)">
    <rect width="340" height="80" rx="16" fill="#1e293b" stroke="#334155" stroke-width="1"/>
    <text x="20" y="32" fill="#ffffff" font-size="15" font-weight="700">KA 1184 • 12 Kereta (SF12)</text>
    <text x="20" y="54" fill="#94a3b8" font-size="12">Laporan Komunitas: <tspan fill="#34d399">1 mnt yang lalu</tspan></text>
  </g>

  <!-- Car by car density visual -->
  <g transform="translate(20, 205)">
    <rect width="340" height="240" rx="20" fill="#1e293b" stroke="#334155" stroke-width="1"/>
    <text x="20" y="30" fill="#ffffff" font-size="14" font-weight="700">Peta Posisi Gerbong</text>
    
    <!-- Train Cars -->
    <!-- Car 1 (Women) -->
    <rect x="20" y="50" width="300" height="34" rx="8" fill="#f43f5e" fill-opacity="0.15" stroke="#f43f5e" stroke-width="1"/>
    <text x="35" y="72" fill="#fda4af" font-size="11" font-weight="600">Gerbong 1 (Khusus Wanita)</text>
    <text x="260" y="72" fill="#f43f5e" font-size="11" font-weight="700">🔴 Padat</text>

    <!-- Car 2-3 -->
    <rect x="20" y="90" width="300" height="34" rx="8" fill="#ef4444" fill-opacity="0.15" stroke="#ef4444" stroke-width="1"/>
    <text x="35" y="112" fill="#fca5a5" font-size="11" font-weight="600">Gerbong 2 &amp; 3</text>
    <text x="260" y="112" fill="#ef4444" font-size="11" font-weight="700">🔴 Padat</text>

    <!-- Car 4-5 (Lengang) -->
    <rect x="20" y="130" width="300" height="34" rx="8" fill="#10b981" fill-opacity="0.2" stroke="#10b981" stroke-width="1.5"/>
    <text x="35" y="152" fill="#6ee7b7" font-size="11" font-weight="700">⭐ Gerbong 4 &amp; 5 (Rekomendasi)</text>
    <text x="250" y="152" fill="#34d399" font-size="11" font-weight="700">🟢 Lengang</text>

    <!-- Car 6-8 -->
    <rect x="20" y="170" width="300" height="34" rx="8" fill="#f59e0b" fill-opacity="0.15" stroke="#f59e0b" stroke-width="1"/>
    <text x="35" y="192" fill="#fde68a" font-size="11" font-weight="600">Gerbong 6, 7 &amp; 8</text>
    <text x="255" y="192" fill="#f59e0b" font-size="11" font-weight="700">🟡 Sedang</text>
  </g>

  <!-- Submit Report Card -->
  <g transform="translate(20, 465)">
    <rect width="340" height="240" rx="20" fill="#1e293b" stroke="#334155" stroke-width="1"/>
    <text x="20" y="32" fill="#ffffff" font-size="14" font-weight="700">Bantu Sesama Pejuang Kereta</text>
    <text x="20" y="52" fill="#94a3b8" font-size="12">Bagikan kondisi gerbongmu saat ini:</text>

    <g transform="translate(20, 75)">
      <rect width="90" height="70" rx="12" fill="#10b981" fill-opacity="0.2" stroke="#10b981" stroke-width="1"/>
      <text x="45" y="35" text-anchor="middle" fill="#ffffff" font-size="20">🟢</text>
      <text x="45" y="58" text-anchor="middle" fill="#6ee7b7" font-size="11" font-weight="600">Lengang</text>

      <rect x="105" y="0" width="90" height="70" rx="12" fill="#f59e0b" fill-opacity="0.2" stroke="#f59e0b" stroke-width="1"/>
      <text x="150" y="35" text-anchor="middle" fill="#ffffff" font-size="20">🟡</text>
      <text x="150" y="58" text-anchor="middle" fill="#fde68a" font-size="11" font-weight="600">Sedang</text>

      <rect x="210" y="0" width="90" height="70" rx="12" fill="#ef4444" fill-opacity="0.2" stroke="#ef4444" stroke-width="1"/>
      <text x="255" y="35" text-anchor="middle" fill="#ffffff" font-size="20">🔴</text>
      <text x="255" y="58" text-anchor="middle" fill="#fca5a5" font-size="11" font-weight="600">Padat</text>
    </g>

    <rect x="20" y="165" width="300" height="44" rx="12" fill="#2563eb"/>
    <text x="170" y="192" text-anchor="middle" fill="#ffffff" font-size="13" font-weight="700">Kirim Laporan Cepat</text>
  </g>
</svg>"""

with open(os.path.join(screenshots_dir, "screen-crowd.svg"), "w", encoding="utf-8") as f:
  f.write(crowd_svg)

# 5. Station Guide Screen SVG
station_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 780" width="380" height="780" style="background:#0f172a; font-family:'Plus Jakarta Sans', system-ui, sans-serif;">
  <rect width="380" height="85" fill="#1e293b"/>
  <text x="24" y="52" fill="#ffffff" font-size="18" font-weight="700">🏢 Info &amp; Fasilitas Stasiun</text>

  <!-- Station Header -->
  <g transform="translate(20, 105)">
    <rect width="340" height="100" rx="20" fill="#1e293b" stroke="#334155" stroke-width="1"/>
    <text x="20" y="35" fill="#ffffff" font-size="18" font-weight="800">Stasiun Manggarai (MRI)</text>
    <text x="20" y="56" fill="#94a3b8" font-size="12">Hub Transit Terbesar Jabodetabek</text>
    <text x="20" y="80" fill="#38bdf8" font-size="11" font-weight="600">♿ Ramah Kursi Roda • 🛗 Ada Lift &amp; Eskalator</text>
  </g>

  <!-- Amenities Grid -->
  <g transform="translate(20, 220)">
    <rect width="340" height="230" rx="20" fill="#1e293b" stroke="#334155" stroke-width="1"/>
    <text x="20" y="30" fill="#ffffff" font-size="14" font-weight="700">Fasilitas Utama Stasiun</text>

    <rect x="20" y="48" width="145" height="75" rx="12" fill="#0f172a"/>
    <text x="35" y="76" fill="#38bdf8" font-size="18">🛗</text>
    <text x="35" y="96" fill="#ffffff" font-size="12" font-weight="600">Lift &amp; Eskalator</text>
    <text x="35" y="112" fill="#94a3b8" font-size="10">Peron 1 s.d 12</text>

    <rect x="175" y="48" width="145" height="75" rx="12" fill="#0f172a"/>
    <text x="190" y="76" fill="#4ade80" font-size="18">🕌</text>
    <text x="190" y="96" fill="#ffffff" font-size="12" font-weight="600">Musholla</text>
    <text x="190" y="112" fill="#94a3b8" font-size="10">Lantai 2 &amp; Peron</text>

    <rect x="20" y="135" width="145" height="75" rx="12" fill="#0f172a"/>
    <text x="35" y="163" fill="#f59e0b" font-size="18">🚻</text>
    <text x="35" y="183" fill="#ffffff" font-size="12" font-weight="600">Toilet Bersih</text>
    <text x="35" y="199" fill="#94a3b8" font-size="10">Pria, Wanita, Difabel</text>

    <rect x="175" y="135" width="145" height="75" rx="12" fill="#0f172a"/>
    <text x="190" y="163" fill="#a855f7" font-size="18">🏪</text>
    <text x="190" y="183" fill="#ffffff" font-size="12" font-weight="600">Minimarket &amp; ATM</text>
    <text x="190" y="199" fill="#94a3b8" font-size="10">Lantai Utama</text>
  </g>

  <!-- Nearby Transportation -->
  <g transform="translate(20, 465)">
    <rect width="340" height="240" rx="20" fill="#1e293b" stroke="#334155" stroke-width="1"/>
    <text x="20" y="32" fill="#ffffff" font-size="14" font-weight="700">Integrasi Transportasi Lanjutan</text>
    
    <rect x="20" y="50" width="300" height="50" rx="10" fill="#0f172a"/>
    <text x="35" y="72" fill="#ffffff" font-size="12" font-weight="600">TransJakarta (Halte Manggarai)</text>
    <text x="35" y="88" fill="#94a3b8" font-size="10">Koridor 4, 4D • Terhubung skybridge</text>

    <rect x="20" y="110" width="300" height="50" rx="10" fill="#0f172a"/>
    <text x="35" y="132" fill="#ffffff" font-size="12" font-weight="600">Titik Jemput Ojek Online</text>
    <text x="35" y="148" fill="#94a3b8" font-size="10">Pintu Barat &amp; Pintu Timur</text>

    <rect x="20" y="170" width="300" height="50" rx="10" fill="#0f172a"/>
    <text x="35" y="192" fill="#ffffff" font-size="12" font-weight="600">Mikrotrans / Angkot</text>
    <text x="35" y="208" fill="#94a3b8" font-size="10">JAK-86, JAK-85</text>
  </g>
</svg>"""

with open(os.path.join(screenshots_dir, "screen-station.svg"), "w", encoding="utf-8") as f:
  f.write(station_svg)

# 6. General Placeholder SVG
placeholder_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 780" width="380" height="780" style="background:#0f172a; font-family:'Plus Jakarta Sans', system-ui, sans-serif;">
  <rect width="380" height="780" fill="#1e293b"/>
  <rect x="20" y="20" width="340" height="740" rx="24" fill="#0f172a" stroke="#334155" stroke-dasharray="6,6" stroke-width="2"/>
  
  <g transform="translate(190, 340)">
    <circle cx="0" cy="0" r="40" fill="#2563eb" fill-opacity="0.2"/>
    <text x="0" y="10" text-anchor="middle" fill="#60a5fa" font-size="32">📸</text>
    <text x="0" y="65" text-anchor="middle" fill="#ffffff" font-size="16" font-weight="700">Tangkapan Layar</text>
    <text x="0" y="90" text-anchor="middle" fill="#94a3b8" font-size="12">Tempatkan gambar aplikasi di sini</text>
    <text x="0" y="115" text-anchor="middle" fill="#64748b" font-size="11">(assets/screenshots/*.png)</text>
  </g>
</svg>"""

with open(os.path.join(screenshots_dir, "placeholder-screen.svg"), "w", encoding="utf-8") as f:
  f.write(placeholder_svg)

# 7. QR Code SVG
qr_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="200" height="200" style="background:#ffffff; border-radius:12px;">
  <!-- Mock QR Pattern -->
  <rect x="15" y="15" width="50" height="50" rx="6" fill="#1e293b"/>
  <rect x="25" y="25" width="30" height="30" rx="2" fill="#ffffff"/>
  <rect x="33" y="33" width="14" height="14" rx="2" fill="#1d4ed8"/>

  <rect x="135" y="15" width="50" height="50" rx="6" fill="#1e293b"/>
  <rect x="145" y="25" width="30" height="30" rx="2" fill="#ffffff"/>
  <rect x="153" y="33" width="14" height="14" rx="2" fill="#1d4ed8"/>

  <rect x="15" y="135" width="50" height="50" rx="6" fill="#1e293b"/>
  <rect x="25" y="145" width="30" height="30" rx="2" fill="#ffffff"/>
  <rect x="33" y="153" width="14" height="14" rx="2" fill="#1d4ed8"/>

  <!-- Center Decorative Icon -->
  <circle cx="100" cy="100" r="22" fill="#1d4ed8"/>
  <text x="100" y="106" text-anchor="middle" fill="#ffffff" font-size="14" font-weight="800">TK</text>

  <!-- Random Grid Matrix for realistic look -->
  <rect x="75" y="20" width="8" height="16" fill="#1e293b"/>
  <rect x="90" y="20" width="16" height="8" fill="#1e293b"/>
  <rect x="110" y="25" width="12" height="12" fill="#1e293b"/>
  <rect x="75" y="45" width="14" height="8" fill="#1e293b"/>
  <rect x="100" y="45" width="18" height="14" fill="#1e293b"/>
  
  <rect x="20" y="75" width="14" height="8" fill="#1e293b"/>
  <rect x="40" y="80" width="8" height="16" fill="#1e293b"/>
  <rect x="55" y="75" width="12" height="24" fill="#1e293b"/>
  <rect x="135" y="75" width="16" height="12" fill="#1e293b"/>
  <rect x="160" y="85" width="15" height="14" fill="#1e293b"/>

  <rect x="75" y="135" width="16" height="14" fill="#1e293b"/>
  <rect x="100" y="140" width="12" height="20" fill="#1e293b"/>
  <rect x="120" y="135" width="18" height="10" fill="#1e293b"/>
  <rect x="145" y="145" width="12" height="16" fill="#1e293b"/>
  <rect x="165" y="135" width="15" height="15" fill="#1e293b"/>

  <rect x="75" y="165" width="22" height="15" fill="#1e293b"/>
  <rect x="110" y="170" width="14" height="12" fill="#1e293b"/>
  <rect x="135" y="170" width="25" height="12" fill="#1e293b"/>
  <rect x="170" y="160" width="10" height="22" fill="#1e293b"/>
</svg>"""

with open(os.path.join(screenshots_dir, "qr-code.svg"), "w", encoding="utf-8") as f:
  f.write(qr_svg)

print("All mockup graphics successfully generated!")

