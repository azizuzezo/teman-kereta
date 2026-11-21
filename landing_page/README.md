# Landing Page — Teman Kereta (TK)

Landing page modern, cepat, dan ringan untuk aplikasi **Teman Kereta**.

---

## 🖼️ Panduan Menaruh Gambar Screenshot (`.webp` / `.png`)

Untuk menjaga agar landing page sangat ringan dan cepat dimuat (*fast loading*), sangat disarankan mengonversi gambar tangkapan layar ke format **`.webp`** (atau tetap bisa menggunakan `.png`).

Cukup simpan file gambar screenshot ke dalam folder:
📁 **`landing_page/assets/screenshots/`**

| Nama File (`.webp` disarankan) | Posisi di Landing Page |
| :--- | :--- |
| **`hero-preview.webp`** *(atau `.png`)* | Layar Mockup HP utama di Hero Section (paling atas) |
| **`screen-schedule.webp`** *(atau `.png`)* | Tab: Jadwal & Keberangkatan |
| **`screen-tracking.webp`** *(atau `.png`)* | Tab: Posisi & Live Tracking |
| **`screen-alarm.webp`** *(atau `.png`)* | Tab: Pengingat Sisa Stasiun & Alarm |
| **`screen-crowd.webp`** *(atau `.png`)* | Tab: Kepadatan Gerbong Real-Time |
| **`screen-station.webp`** *(atau `.png`)* | Tab: Panduan & Fasilitas Stasiun |

> 💡 **Sistem Otomatis (Fallback Cascade)**:
> Sistem akan secara otomatis mencari file `.webp` terlebih dahulu. Jika file `.webp` belum ada, ia akan mencari file `.png`. Jika keduanya belum ada, maka grafik vektor `.svg` bawaan yang bersih akan ditampilkan secara otomatis.

---

## 📥 Unduhan

Sejak rilis resmi di Google Play, situs hanya punya **satu tombol unduhan**:
[Teman Kereta di Google Play](https://play.google.com/store/apps/details?id=id.temankereta.teman_kereta&hl=id).
Tidak ada lagi tombol atau tautan APK di halaman mana pun.

APK tetap dibangun setiap rilis dengan `scripts/build-release.ps1`, diunggah
ke Cloudflare R2 (bucket `temankereta-releases`, domain
`dl.temankereta.web.id`), dan dicatat di tabel `app_releases` Supabase.
Itu dipakai untuk notifikasi pembaruan di dalam aplikasi bagi pengguna yang
dulu memasang lewat APK, bukan untuk situs ini.

---

## 📝 Halaman konten

- `/artikel/` — pusat artikel dan panduan KRL.
- `/artikel/apa-itu-teman-kereta/` — pengenalan aplikasi.
- `/artikel/aplikasi-alarm-turun-stasiun-krl/`, `/artikel/notifikasi-krl-commuter-line/`, `/artikel/cek-posisi-dan-jadwal-krl-commuter-line/` — artikel SEO (alarm, notifikasi, jadwal/rute).
- `/artikel/tips-tidak-kebablasan-stasiun-krl/` — tips perjalanan.
- `/tentang/` — halaman tentang aplikasi dan pengelola.
- `/terms` — syarat dan ketentuan (dipakai juga untuk review app TikTok/Meta).

Setiap halaman baru harus ditambahkan ke `sitemap.xml` dan ditautkan dari
halaman lain agar mudah ditemukan Google.

---

## 🚀 Cara Menjalankan

Buka langsung file `index.html` dengan browser, atau jalankan local server:
```bash
cd "c:\Projet\Teman Kereta\landing_page"
python -m http.server 3000
```
Lalu buka: `http://localhost:3000`
