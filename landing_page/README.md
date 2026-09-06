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

## 📥 File Unduhan APK

File APK diletakkan di:
`landing_page/assets/downloads/teman-kereta-v1.0.apk`

---

## 🚀 Cara Menjalankan

Buka langsung file `index.html` dengan browser, atau jalankan local server:
```bash
cd "c:\Projet\Teman Kereta\landing_page"
python -m http.server 3000
```
Lalu buka: `http://localhost:3000`
