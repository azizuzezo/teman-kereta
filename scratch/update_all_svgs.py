import os

screenshots_dir = r"c:\Projet\Teman Kereta\landing_page\assets\screenshots"

# 1. Screen Tracking SVG
tracking_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 780" width="380" height="780" style="background:#090d16; font-family:'Plus Jakarta Sans', -apple-system, system-ui, sans-serif;">
  <defs>
    <linearGradient id="surfaceGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#151d2f"/>
      <stop offset="100%" stop-color="#0f172a"/>
    </linearGradient>
  </defs>
  
  <!-- Header -->
  <rect width="380" height="85" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
  <text x="24" y="52" fill="#f8fafc" font-size="17" font-weight="700">Posisi &amp; Live Tracking</text>
  
  <!-- Map Route Area -->
  <rect x="16" y="100" width="348" height="280" rx="20" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
  
  <!-- Grid lines -->
  <line x1="16" y1="170" x2="364" y2="170" stroke="#1e293b" stroke-width="1" stroke-dasharray="4,4"/>
  <line x1="16" y1="240" x2="364" y2="240" stroke="#1e293b" stroke-width="1" stroke-dasharray="4,4"/>
  <line x1="16" y1="310" x2="364" y2="310" stroke="#1e293b" stroke-width="1" stroke-dasharray="4,4"/>

  <!-- Route Path -->
  <path d="M 50 160 Q 180 130 310 230 T 190 330" fill="none" stroke="#ef4444" stroke-width="5" stroke-linecap="round"/>
  
  <circle cx="50" cy="160" r="6" fill="#ffffff" stroke="#ef4444" stroke-width="2.5"/>
  <text x="45" y="140" fill="#cbd5e1" font-size="11" font-weight="600">Jakarta Kota</text>

  <circle cx="180" cy="175" r="6" fill="#ffffff" stroke="#ef4444" stroke-width="2.5"/>
  <text x="170" y="158" fill="#cbd5e1" font-size="11" font-weight="600">Manggarai</text>

  <!-- Live Train Pin Indicator -->
  <g transform="translate(140, 155)">
    <circle cx="14" cy="14" r="14" fill="#2563eb" stroke="#ffffff" stroke-width="2"/>
    <circle cx="14" cy="14" r="4" fill="#ffffff"/>
  </g>

  <circle cx="310" cy="230" r="6" fill="#ffffff" stroke="#ef4444" stroke-width="2.5"/>
  <text x="300" y="255" fill="#cbd5e1" font-size="11" font-weight="600">Depok</text>

  <circle cx="190" cy="330" r="6" fill="#ffffff" stroke="#ef4444" stroke-width="2.5"/>
  <text x="180" y="355" fill="#cbd5e1" font-size="11" font-weight="600">Bogor</text>

  <!-- Live Tracking Detail -->
  <g transform="translate(16, 400)">
    <rect width="348" height="150" rx="18" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <rect x="20" y="20" width="90" height="20" rx="6" fill="#2563eb" fill-opacity="0.15"/>
    <text x="28" y="34" fill="#60a5fa" font-size="10" font-weight="700" letter-spacing="0.5">KERETA AKTIF</text>
    
    <text x="20" y="68" fill="#ffffff" font-size="17" font-weight="800">KA 1182 • Bogor Line</text>
    <text x="20" y="92" fill="#94a3b8" font-size="12">Stasiun Berikutnya: <tspan fill="#34d399" font-weight="600">Tebet (1.8 km)</tspan></text>
    <text x="20" y="114" fill="#94a3b8" font-size="12">Estimasi Tiba: <tspan fill="#fbbf24" font-weight="600">07:49 WIB (3 mnt)</tspan></text>
    
    <rect x="20" y="130" width="308" height="6" rx="3" fill="#1e293b"/>
    <rect x="20" y="130" width="220" height="6" rx="3" fill="#2563eb"/>
  </g>

  <!-- Route Steps -->
  <g transform="translate(16, 568)">
    <rect width="348" height="180" rx="18" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <text x="20" y="28" fill="#ffffff" font-size="14" font-weight="700">Panduan Transit &amp; Peron</text>
    
    <circle cx="28" cy="60" r="4.5" fill="#3b82f6"/>
    <line x1="28" y1="65" x2="28" y2="115" stroke="#334155" stroke-width="2" stroke-dasharray="2,2"/>
    <text x="44" y="64" fill="#e2e8f0" font-size="12" font-weight="600">Naik Peron 3 (Arah Manggarai)</text>
    
    <circle cx="28" cy="120" r="4.5" fill="#f59e0b"/>
    <text x="44" y="124" fill="#e2e8f0" font-size="12" font-weight="600">Transit di Stasiun Manggarai</text>
    <text x="44" y="142" fill="#94a3b8" font-size="11">Pindah ke Peron 11 (Arah Bogor)</text>
  </g>
</svg>"""

with open(os.path.join(screenshots_dir, "screen-tracking.svg"), "w", encoding="utf-8") as f:
  f.write(tracking_svg)

# 2. Screen Alarm SVG
alarm_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 780" width="380" height="780" style="background:#090d16; font-family:'Plus Jakarta Sans', -apple-system, system-ui, sans-serif;">
  <defs>
    <linearGradient id="surfaceGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#151d2f"/>
      <stop offset="100%" stop-color="#0f172a"/>
    </linearGradient>
    <linearGradient id="alarmCardGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ea580c"/>
      <stop offset="100%" stop-color="#c2410c"/>
    </linearGradient>
  </defs>

  <rect width="380" height="85" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
  <text x="24" y="52" fill="#f8fafc" font-size="17" font-weight="700">Pengingat &amp; Alarm Stasiun</text>

  <!-- Alarm Notification Card -->
  <g transform="translate(20, 108)">
    <rect width="340" height="260" rx="22" fill="url(#alarmCardGrad)" stroke="#f97316" stroke-width="1"/>
    
    <circle cx="170" cy="58" r="28" fill="#ffffff" fill-opacity="0.15"/>
    <circle cx="170" cy="58" r="12" fill="#ffffff"/>
    
    <text x="170" y="118" text-anchor="middle" fill="#ffffff" font-size="18" font-weight="800">Bersiap Turun</text>
    <text x="170" y="144" text-anchor="middle" fill="#fed7aa" font-size="12">Kereta mendekati stasiun tujuan:</text>
    <text x="170" y="174" text-anchor="middle" fill="#ffffff" font-size="22" font-weight="800">Stasiun Tebet</text>
    <text x="170" y="198" text-anchor="middle" fill="#fed7aa" font-size="12 font-weight-500">1 Stasiun Lagi • Estimasi 2 Menit</text>
    
    <rect x="36" y="214" width="268" height="26" rx="13" fill="#000000" fill-opacity="0.25"/>
    <text x="170" y="231" text-anchor="middle" fill="#ffffff" font-size="10.5" font-weight="600">Getaran &amp; Nada Dering Aktif</text>
  </g>

  <!-- Settings List -->
  <g transform="translate(20, 395)">
    <rect width="340" height="340" rx="20" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <text x="20" y="32" fill="#ffffff" font-size="14" font-weight="700">Pengaturan Alarm Pintar</text>
    
    <rect x="20" y="52" width="300" height="62" rx="14" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <text x="36" y="78" fill="#ffffff" font-size="12.5" font-weight="600">Peringatan Sebelum Tujuan</text>
    <text x="36" y="96" fill="#94a3b8" font-size="11">Aktifkan 1 atau 2 stasiun sebelumnya</text>
    <rect x="254" y="70" width="46" height="26" rx="13" fill="#2563eb"/>
    <circle cx="284" cy="83" r="9" fill="#ffffff"/>

    <rect x="20" y="126" width="300" height="62" rx="14" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <text x="36" y="152" fill="#ffffff" font-size="12.5" font-weight="600">Peringatan Stasiun Transit</text>
    <text x="36" y="170" fill="#94a3b8" font-size="11">Alarm khusus perpindahan jalur</text>
    <rect x="254" y="144" width="46" height="26" rx="13" fill="#2563eb"/>
    <circle cx="284" cy="157" r="9" fill="#ffffff"/>

    <rect x="20" y="200" width="300" height="62" rx="14" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <text x="36" y="226" fill="#ffffff" font-size="12.5" font-weight="600">Pola Getar Kuat</text>
    <text x="36" y="244" fill="#94a3b8" font-size="11">Getaran ritmik saat berada di saku</text>
    <rect x="254" y="218" width="46" height="26" rx="13" fill="#2563eb"/>
    <circle cx="284" cy="231" r="9" fill="#ffffff"/>
  </g>
</svg>"""

with open(os.path.join(screenshots_dir, "screen-alarm.svg"), "w", encoding="utf-8") as f:
  f.write(alarm_svg)

# 3. Screen Crowd SVG
crowd_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 780" width="380" height="780" style="background:#090d16; font-family:'Plus Jakarta Sans', -apple-system, system-ui, sans-serif;">
  <defs>
    <linearGradient id="surfaceGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#151d2f"/>
      <stop offset="100%" stop-color="#0f172a"/>
    </linearGradient>
  </defs>

  <rect width="380" height="85" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
  <text x="24" y="52" fill="#f8fafc" font-size="17" font-weight="700">Kepadatan Gerbong Real-Time</text>

  <g transform="translate(20, 105)">
    <rect width="340" height="74" rx="16" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <text x="20" y="32" fill="#ffffff" font-size="14.5" font-weight="700">KA 1184 • Rangkaian 12 Kereta</text>
    <text x="20" y="52" fill="#94a3b8" font-size="11.5">Laporan Terkini: <tspan fill="#34d399" font-weight="600">1 mnt yang lalu</tspan></text>
  </g>

  <!-- Train Density Map -->
  <g transform="translate(20, 195)">
    <rect width="340" height="240" rx="20" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <text x="20" y="28" fill="#ffffff" font-size="13.5" font-weight="700">Status Per Gerbong</text>
    
    <!-- Car 1 -->
    <rect x="20" y="46" width="300" height="34" rx="8" fill="#f43f5e" fill-opacity="0.1" stroke="#f43f5e" stroke-width="1"/>
    <text x="32" y="68" fill="#fda4af" font-size="11" font-weight="600">Gerbong 1 (Khusus Wanita)</text>
    <text x="265" y="68" fill="#f43f5e" font-size="11" font-weight="700">Padat</text>

    <!-- Car 2-3 -->
    <rect x="20" y="86" width="300" height="34" rx="8" fill="#ef4444" fill-opacity="0.1" stroke="#ef4444" stroke-width="1"/>
    <text x="32" y="108" fill="#fca5a5" font-size="11" font-weight="600">Gerbong 2 &amp; 3</text>
    <text x="265" y="108" fill="#ef4444" font-size="11" font-weight="700">Padat</text>

    <!-- Car 4-5 (Recommended) -->
    <rect x="20" y="126" width="300" height="34" rx="8" fill="#10b981" fill-opacity="0.15" stroke="#10b981" stroke-width="1.5"/>
    <text x="32" y="148" fill="#6ee7b7" font-size="11" font-weight="700">Gerbong 4 &amp; 5 (Rekomendasi)</text>
    <text x="255" y="148" fill="#34d399" font-size="11" font-weight="700">Lengang</text>

    <!-- Car 6-8 -->
    <rect x="20" y="166" width="300" height="34" rx="8" fill="#f59e0b" fill-opacity="0.1" stroke="#f59e0b" stroke-width="1"/>
    <text x="32" y="188" fill="#fde68a" font-size="11" font-weight="600">Gerbong 6, 7 &amp; 8</text>
    <text x="260" y="188" fill="#f59e0b" font-size="11" font-weight="700">Sedang</text>
  </g>

  <!-- Submit Report -->
  <g transform="translate(20, 455)">
    <rect width="340" height="240" rx="20" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <text x="20" y="30" fill="#ffffff" font-size="13.5" font-weight="700">Bantu Pengguna Lain</text>
    <text x="20" y="50" fill="#94a3b8" font-size="11.5">Bagikan kondisi gerbongmu saat ini:</text>

    <g transform="translate(20, 72)">
      <rect width="90" height="66" rx="12" fill="#10b981" fill-opacity="0.15" stroke="#10b981" stroke-width="1"/>
      <circle cx="45" cy="24" r="7" fill="#10b981"/>
      <text x="45" y="52" text-anchor="middle" fill="#6ee7b7" font-size="11" font-weight="600">Lengang</text>

      <rect x="105" y="0" width="90" height="66" rx="12" fill="#f59e0b" fill-opacity="0.15" stroke="#f59e0b" stroke-width="1"/>
      <circle cx="150" cy="24" r="7" fill="#f59e0b"/>
      <text x="150" y="52" text-anchor="middle" fill="#fde68a" font-size="11" font-weight="600">Sedang</text>

      <rect x="210" y="0" width="90" height="66" rx="12" fill="#ef4444" fill-opacity="0.15" stroke="#ef4444" stroke-width="1"/>
      <circle cx="255" cy="24" r="7" fill="#ef4444"/>
      <text x="255" y="52" text-anchor="middle" fill="#fca5a5" font-size="11" font-weight="600">Padat</text>
    </g>

    <rect x="20" y="160" width="300" height="42" rx="12" fill="#2563eb"/>
    <text x="170" y="186" text-anchor="middle" fill="#ffffff" font-size="12.5" font-weight="700">Kirim Laporan</text>
  </g>
</svg>"""

with open(os.path.join(screenshots_dir, "screen-crowd.svg"), "w", encoding="utf-8") as f:
  f.write(crowd_svg)

# 4. Screen Station SVG
station_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 780" width="380" height="780" style="background:#090d16; font-family:'Plus Jakarta Sans', -apple-system, system-ui, sans-serif;">
  <defs>
    <linearGradient id="surfaceGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#151d2f"/>
      <stop offset="100%" stop-color="#0f172a"/>
    </linearGradient>
  </defs>

  <rect width="380" height="85" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
  <text x="24" y="52" fill="#f8fafc" font-size="17" font-weight="700">Informasi &amp; Fasilitas Stasiun</text>

  <!-- Station Header -->
  <g transform="translate(20, 105)">
    <rect width="340" height="92" rx="18" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <text x="20" y="32" fill="#ffffff" font-size="17" font-weight="800">Stasiun Manggarai (MRI)</text>
    <text x="20" y="52" fill="#94a3b8" font-size="11.5">Hub Transit Utama KRL Jabodetabek</text>
    <text x="20" y="74" fill="#38bdf8" font-size="11" font-weight="600">Akses Ramah Kursi Roda • Lift &amp; Eskalator</text>
  </g>

  <!-- Facilities Grid -->
  <g transform="translate(20, 212)">
    <rect width="340" height="230" rx="20" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <text x="20" y="28" fill="#ffffff" font-size="13.5" font-weight="700">Fasilitas Utama Stasiun</text>

    <rect x="20" y="44" width="145" height="75" rx="12" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <circle cx="40" cy="68" r="8" fill="#2563eb" fill-opacity="0.2"/>
    <circle cx="40" cy="68" r="3" fill="#38bdf8"/>
    <text x="56" y="72" fill="#ffffff" font-size="12" font-weight="600">Lift &amp; Eskalator</text>
    <text x="28" y="102" fill="#94a3b8" font-size="10">Peron 1 s.d 12</text>

    <rect x="175" y="44" width="145" height="75" rx="12" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <circle cx="195" cy="68" r="8" fill="#10b981" fill-opacity="0.2"/>
    <circle cx="195" cy="68" r="3" fill="#34d399"/>
    <text x="211" y="72" fill="#ffffff" font-size="12" font-weight="600">Musholla</text>
    <text x="183" y="102" fill="#94a3b8" font-size="10">Lantai 2 &amp; Peron</text>

    <rect x="20" y="132" width="145" height="75" rx="12" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <circle cx="40" cy="156" r="8" fill="#f59e0b" fill-opacity="0.2"/>
    <circle cx="40" cy="156" r="3" fill="#fbbf24"/>
    <text x="56" y="160" fill="#ffffff" font-size="12" font-weight="600">Toilet Bersih</text>
    <text x="28" y="190" fill="#94a3b8" font-size="10">Umum &amp; Difabel</text>

    <rect x="175" y="132" width="145" height="75" rx="12" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <circle cx="195" cy="156" r="8" fill="#8b5cf6" fill-opacity="0.2"/>
    <circle cx="195" cy="156" r="3" fill="#a78bfa"/>
    <text x="211" y="160" fill="#ffffff" font-size="12" font-weight="600">Minimarket &amp; ATM</text>
    <text x="183" y="190" fill="#94a3b8" font-size="10">Lantai Concourse</text>
  </g>

  <!-- Connections -->
  <g transform="translate(20, 458)">
    <rect width="340" height="240" rx="20" fill="url(#surfaceGrad)" stroke="#1e293b" stroke-width="1"/>
    <text x="20" y="30" fill="#ffffff" font-size="13.5" font-weight="700">Integrasi Transportasi Lanjutan</text>
    
    <rect x="20" y="48" width="300" height="50" rx="12" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <text x="35" y="70" fill="#ffffff" font-size="12" font-weight="600">TransJakarta (Halte Manggarai)</text>
    <text x="35" y="86" fill="#94a3b8" font-size="10.5">Koridor 4, 4D • Terhubung Skybridge</text>

    <rect x="20" y="108" width="300" height="50" rx="12" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <text x="35" y="130" fill="#ffffff" font-size="12" font-weight="600">Titik Jemput Ojek Online</text>
    <text x="35" y="146" fill="#94a3b8" font-size="10.5">Pintu Barat &amp; Pintu Timur</text>

    <rect x="20" y="168" width="300" height="50" rx="12" fill="#0f172a" stroke="#1e293b" stroke-width="1"/>
    <text x="35" y="190" fill="#ffffff" font-size="12" font-weight="600">Mikrotrans / JakLingko</text>
    <text x="35" y="206" fill="#94a3b8" font-size="10.5">JAK-86, JAK-85</text>
  </g>
</svg>"""

with open(os.path.join(screenshots_dir, "screen-station.svg"), "w", encoding="utf-8") as f:
  f.write(station_svg)

print("All screenshots SVGs updated cleanly!")
