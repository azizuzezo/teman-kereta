# Teman Kereta — Persiapan Play Console (v1.0.16, versionCode 17)

> **Status 2026-10-15:** poin 0.1 (hapus akun), 0.2 (laporkan/blokir forum), dan 0.3 (kebijakan privasi + halaman
> hapus akun) **sudah dikodekan** di v1.0.16. Syarat sebelum rilis: migrasi
> `supabase/migrations/20261015090000_account_deletion_and_forum_moderation.sql` **harus diterapkan ke database
> produksi** dan situs utama (`landing_page/`, Cloudflare Pages `temankereta-landing`) **harus di-deploy ulang**; tanpa itu
> tombol hapus akun dan laporan di app akan gagal dan URL kebijakan privasi/penghapusan akun belum aktif. Halaman
> privasi dan hapus akun kini ada di situs utama (bukan di panel admin). URL penghapusan data untuk Data safety:
> `https://temankereta.web.id/delete-account`. URL lama `panel.temankereta.web.id/privacy` dan `/delete-account` hanya
> redirect 308 ke URL baru, jangan dipakai di Play Console. Poin 0.4 (email) dan 0.5 (password database) masih menunggu Anda.

Package: `id.temankereta.teman_kereta`. Semua jawaban di bawah disusun dari kode di repo
(manifest, `supabase/migrations`, `lib/`), bukan tebakan. Teks bertanda **[ENGLISH]** sengaja
dalam bahasa Inggris karena formulir Play Console ditinjau oleh reviewer internasional.

---

## 0. Yang HARUS diputuskan/diperbaiki sebelum submit

| # | Masalah | Kenapa penting | Tindakan |
|---|---------|----------------|----------|
| 1 | **Tidak ada fitur hapus akun di dalam app.** Halaman Privasi app berkata "hubungi kami lewat kontak", sedangkan kebijakan privasi web berkata "menghapus akun melalui aplikasi". | Kebijakan Play untuk app yang bisa membuat akun: wajib ada jalur hapus akun **di dalam app** DAN **URL web** untuk meminta penghapusan. Ini kandidat penolakan. | Tambah tombol "Hapus akun" di Profil + halaman web penghapusan (boleh seperti `landing_page/threads-data-deletion`). Isi URL-nya di Data safety. |
| 2 | **Forum (konten buatan pengguna) tidak punya tombol Laporkan/Blokir.** | Kebijakan UGC Play mewajibkan mekanisme melaporkan konten dan memblokir pengguna, plus moderasi. | Tambah "Laporkan" pada post/komentar (cukup menulis ke tabel `reports` + notifikasi admin) dan "Blokir pengguna". |
| 3 | **Kebijakan privasi publik terlalu tipis** dan tidak cocok dengan perilaku app (lihat bagian 3). | Reviewer membandingkan kebijakan dengan Data safety dan izin lokasi latar belakang. | Sudah diganti: teks final ada di `landing_page/privacy.html`; deploy ulang situs utama. |
| 4 | **Email kontak**: sudah disamakan di app dan web menjadi `support@temankereta.web.id`. | Email developer di Play Console harus aktif; kontak privasi yang tidak bisa dibalas bisa jadi pelanggaran. | Pastikan kotak masuk `support@temankereta.web.id` benar-benar menerima email, dan pakai alamat yang sama di Play Console. |
| 5 | `scripts/build-release.ps1` berisi **password database Postgres** (parameter `$DbUrl`) yang ikut ter-commit. | Siapa pun dengan akses repo bisa membaca database produksi. | Ganti password database di Supabase sekarang, lalu pindahkan nilainya ke environment variable. |

Poin 1 dan 2 butuh perubahan kode, jadi AAB harus dibuild ulang (naik ke `1.0.16+17`).
Poin 3 dan 4 tidak mengubah AAB.

---

## 1. Deklarasi izin sensitif (App content → Sensitive app permissions)

### 1a. Izin lokasi latar belakang (`ACCESS_BACKGROUND_LOCATION`)

Play akan meminta: fitur inti yang membutuhkannya, dan **video demo** (30–60 detik, bisa diunggah ke YouTube
berstatus *unlisted*).

**Deskripsi fitur [ENGLISH]:**

> Teman Kereta is a companion app for Jakarta commuter-train (KRL) riders. Its core feature is the
> "destination alert": the rider picks a destination station and the app warns them shortly before the
> train arrives there, so they don't miss their stop — including when the phone is in a pocket or bag with
> the screen off. This requires location access while the app is not on screen, because the rider locks the
> phone during the journey. Location is only monitored during an active trip that the rider started (or
> confirmed after auto-detection). It stops when the trip ends. The user is shown an in-app explanation
> before the system permission dialog and can use all schedule features without granting it.

**Alur untuk video demo** (rekam layar ponsel, dengan narasi/teks):
1. Buka app → Profil → Pengaturan lokasi, tunjukkan penjelasan sebelum dialog izin muncul.
2. Tekan "Izinkan sepanjang waktu" → dialog sistem Android muncul → pilih "Allow all the time".
3. Mulai perjalanan, pilih stasiun tujuan.
4. Tekan Home, kunci layar.
5. Tunjukkan notifikasi "Foreground service" yang terlihat saat perjalanan aktif.
6. Tunjukkan peringatan "sebentar lagi tiba di stasiun X" saat layar mati.
7. Akhiri perjalanan → notifikasi hilang.

### 1b. Foreground service — tipe `location` (`FOREGROUND_SERVICE_LOCATION`)

Service: `ActiveTripLocationService`.

**[ENGLISH]**

> The foreground service keeps GPS tracking alive while the rider is on a trip that they started, so that the
> destination-station alert can fire while the screen is off. A persistent notification is shown for the
> whole duration, and the service stops when the trip ends or the rider cancels it. The user can see and stop
> it at any time from the notification. Without a foreground service, Android would stop location updates
> after a short time in the background and the alert would not fire.

Video: pakai video yang sama dengan 1a (tampilkan notifikasi foreground service).

### 1c. Pengecualian optimasi baterai (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`)

Izin ini ketat. Google hanya mengizinkan jika fungsi inti app **rusak** karena optimasi baterai.

**[ENGLISH]**

> Aggressive battery optimization (Doze/App Standby and OEM task killers) terminates the trip-tracking
> foreground service mid-journey, so the destination alert never fires. The permission is used only to open the
> system dialog that lets the user exempt the app. It is requested only when the user taps "Izinkan
> berjalan bebas di latar belakang" in Settings → Pengaturan lokasi, never at launch.

**Risiko**: tergolong sering ditolak. Jika ditolak, cara paling aman adalah menghapus izin ini dari manifest dan
mengganti tombolnya dengan membuka halaman pengaturan baterai app (`ACTION_APPLICATION_DETAILS_SETTINGS`), yang
tidak butuh izin khusus. Saya sarankan menyiapkan jalur itu sebagai cadangan.

### 1d. Pengenalan aktivitas (`ACTIVITY_RECOGNITION`)

**[ENGLISH]**

> Used only if the rider turns on "Deteksi otomatis naik KRL" (off by default, with an in-app explanation
> first). Activity recognition tells the app that the rider has started a vehicle trip, so it can offer to
> start trip tracking automatically. No activity data is stored or sent to any server.

### 1e. Izin lain (tidak perlu formulir khusus)

`POST_NOTIFICATIONS` (peringatan stasiun & gangguan layanan), `ACCESS_FINE/COARSE_LOCATION`,
`MODIFY_AUDIO_SETTINGS` (alarm tiba di stasiun).

---

## 2. Kebijakan privasi

Isi URL kebijakan privasi di **App content → Privacy policy**. URL yang sudah ada:

`https://temankereta.web.id/privacy`

Teks final ada di `landing_page/privacy.html` (bagian 3 di bawah adalah draf awal). URL harus publik, tanpa login, dan bukan PDF.

---

## 3. Draf kebijakan privasi (draf awal; versi final di `landing_page/privacy.html`)

> **Kebijakan Privasi Teman Kereta**
> Terakhir diperbarui: [isi tanggal deploy]
>
> Teman Kereta ("kami") adalah aplikasi pendamping perjalanan KRL. Kebijakan ini menjelaskan data apa yang
> kami proses, untuk apa, dan pilihan Anda.
>
> **1. Data yang kami proses**
> - **Lokasi (GPS).** Dipakai untuk mencari stasiun terdekat, memandu perjalanan aktif, dan membunyikan peringatan
>   sebelum stasiun tujuan, termasuk saat layar terkunci selama perjalanan aktif. Jika Anda mengaktifkan
>   "Deteksi otomatis naik KRL", posisi GPS Anda dikirim ke server kami sesekali selama perjalanan agar penumpang
>   lain dapat melihat posisi kereta. Data ini tersimpan sementara dan dihapus otomatis paling lama 10 menit,
>   digabung dengan laporan penumpang lain menjadi satu posisi rata-rata per kereta, dan tidak pernah
>   ditampilkan sebagai posisi Anda. Fitur ini nonaktif secara bawaan.
> - **Aktivitas fisik.** Hanya dibaca di perangkat untuk mengenali dimulainya perjalanan; tidak disimpan atau dikirim.
> - **Akun.** Untuk memakai aplikasi, Anda mendaftar dan masuk dengan: email, nama tampilan, username, dan kata sandi (disimpan terenkripsi oleh
>   penyedia autentikasi, kami tidak bisa membacanya). Preferensi seperti stasiun rumah/kantor dan rute favorit
>   tersimpan pada akun Anda.
> - **Forum dan foto.** Postingan, komentar, foto yang Anda unggah, foto profil, dan siapa yang Anda ikuti
>   terlihat oleh pengguna lain.
> - **Token notifikasi.** Pengenal perangkat untuk Firebase Cloud Messaging agar kami dapat mengirim
>   pemberitahuan gangguan layanan dan balasan forum.
> - **Disimpan di perangkat saja.** Riwayat perjalanan, laporan lokal, dan preferensi tampilan.
>
> **2. Yang tidak kami lakukan**
> Kami tidak menjual atau membagikan data lokasi Anda, tidak menampilkan iklan, dan tidak memasang pelacak
> analitik pihak ketiga.
>
> **3. Pemroses data (penyedia layanan)**
> Supabase (basis data, autentikasi, penyimpanan foto) dan Google Firebase Cloud Messaging (notifikasi).
> Data dikirim lewat koneksi terenkripsi (HTTPS).
>
> **4. Penyimpanan dan penghapusan**
> Ping lokasi mentah dihapus dalam 10 menit. Data akun disimpan selama akun aktif. Anda dapat menghapus akun
> dan seluruh data terkait lewat **Profil → Hapus akun** di aplikasi, atau lewat [URL halaman penghapusan],
> atau dengan mengirim email ke [email kontak]. Penghapusan diproses dalam 30 hari.
>
> **5. Pilihan Anda**
> Anda dapat mencabut izin lokasi, aktivitas fisik, dan notifikasi kapan saja di Pengaturan Android. Anda
> juga dapat menghapus akun kapan saja (lihat bagian 4).
>
> **6. Anak-anak**
> Aplikasi ini tidak ditujukan untuk anak di bawah 13 tahun dan kami tidak sengaja mengumpulkan data mereka.
>
> **7. Perubahan kebijakan**
> Perubahan akan dipublikasikan di halaman ini dengan tanggal pembaruan baru.
>
> **8. Kontak**
> [email kontak yang aktif]

Catatan: kalimat "Sentry/crash report" sengaja tidak ada. Build rilis dibuat dengan `SENTRY_DSN` kosong,
jadi pelaporan crash tidak aktif. Jika nanti diaktifkan, kebijakan ini dan Data safety harus diperbarui lebih dulu.

---

## 4. Data safety form

**Pertanyaan umum**

| Pertanyaan | Jawaban |
|---|---|
| Apakah app mengumpulkan atau membagikan data pengguna? | Ya |
| Semua data dienkripsi saat transit? | Ya (HTTPS) |
| Pengguna bisa meminta data dihapus? | Ya — **hanya jika poin 0.1 selesai** (hapus akun di app + URL web) |
| URL penghapusan data | `https://temankereta.web.id/delete-account` |

**Data yang dikumpulkan** (tidak ada yang "dibagikan" ke pihak ketiga; Supabase dan Firebase berstatus
*service provider*/pemroses, yang tidak dihitung sebagai berbagi menurut definisi Google)

| Kategori Play | Jenis | Wajib/Opsional | Tujuan | Catatan |
|---|---|---|---|---|
| Location | Approximate location | Opsional | App functionality | Stasiun terdekat |
| Location | Precise location | Opsional | App functionality | Peringatan stasiun; dikirim ke server hanya jika "Deteksi otomatis" aktif; dihapus ≤10 menit |
| Personal info | Email address | **Wajib** (login wajib untuk memakai app) | Account management | |
| Personal info | Name | Wajib/opsional (nama tampilan bisa diisi nanti) | App functionality, Account management | Nama tampilan |
| Personal info | User IDs | **Wajib** | App functionality, Account management | Username |
| Photos and videos | Photos | Opsional | App functionality | Foto forum & avatar |
| App activity | Other user-generated content | Opsional | App functionality | Postingan & komentar forum |
| Device or other IDs | Device or other IDs | Wajib untuk notifikasi | App functionality | Token FCM |

**Tidak dikumpulkan**: kontak, riwayat browsing, pesan pribadi, data keuangan, kesehatan, kinerja app/crash log
(Sentry nonaktif di build rilis), analytics, iklan.

---

## 5. Pernyataan lain di App content

| Bagian | Jawaban |
|---|---|
| Ads | **Tidak** mengandung iklan |
| App access | **Seluruh app dikunci di balik login** (`app_router.dart`: semua rute selain login/reset/username butuh akun). Pilih "All or some functionality is restricted" dan isi **akun demo** (email + kata sandi) yang sudah terverifikasi emailnya dan sudah punya username, plus langkah: "Buka app → Masuk → masukkan kredensial". Tanpa akun demo yang berfungsi, review hampir pasti ditolak. |
| Target audience | **13 tahun ke atas** (pilih 13–15, 16–17, 18+; jangan pilih di bawah 13 agar tidak terkena kebijakan Families) |
| Content rating (IARC) | Kategori *Utility/Reference*. Kekerasan, seksual, judi, narkoba: **Tidak**. Interaksi pengguna / konten buatan pengguna: **Ya**. Berbagi lokasi dengan pengguna lain: pilih **Ya** secara konservatif karena posisi digabung dari penumpang. Perkiraan hasil: Everyone / 3+ dengan label "Users Interact". |
| News app / COVID-19 / Government / Financial / Health | Semua **Tidak** |
| Foreground service | Lihat 1b |
| Data safety | Lihat bagian 4 |

---

## 6. Store listing (Bahasa Indonesia sebagai bahasa default)

**Nama app** (maks. 30 karakter): `Teman Kereta: Jadwal KRL`  (24)

**Deskripsi singkat** (maks. 80 karakter):
`Jadwal KRL, posisi kereta, dan alarm stasiun tujuan. Gratis, tanpa iklan.`  (73)

**Deskripsi lengkap** (maks. 4000 karakter):

```
Teman Kereta adalah aplikasi untuk pengguna KRL Commuter Line Jabodetabek. Isinya jadwal, posisi kereta di peta, dan alarm yang berbunyi sebelum stasiun tujuanmu.

Alarm stasiun tujuan
Pilih stasiun tujuan, lalu kunci layar. Aplikasi membunyikan peringatan beberapa stasiun sebelum kereta tiba. Jumlah stasiunnya bisa kamu atur.

Jadwal dan rute
Lihat keberangkatan berikutnya dari stasiun yang kamu pilih. Cari rute dari satu stasiun ke stasiun lain, termasuk rute dengan satu kali transit.

Posisi kereta di peta
Posisi kereta ditampilkan dengan label sumbernya: real-time, terakhir diperbarui, atau estimasi dari jadwal. Kamu bisa membedakan data yang diukur dan data yang diperkirakan.

Info gangguan layanan
Notifikasi saat ada gangguan di jalur yang kamu pakai.

Deteksi naik KRL (opsional)
Kalau kamu aktifkan, aplikasi mengenali saat kamu naik kereta dan menawarkan untuk memulai perjalanan. Fitur ini mati secara bawaan. Saat aktif, posisimu dikirim sesekali dan digabung dengan laporan penumpang lain untuk menampilkan posisi kereta.

Tempat di sekitar stasiun
Daftar kuliner, tempat belanja, taman, toilet, dan tempat wisata dekat stasiun. Kamu bisa menambahkan tempat yang belum ada.

Widget layar utama
Keberangkatan berikutnya, status layanan, dan rute harian di layar utama ponsel.

Forum
Tempat bertanya dan berbagi info antarpengguna KRL, bisa disaring per lintas. Setiap postingan dan komentar bisa dilaporkan, dan kamu bisa memblokir pengguna lain.

Riwayat perjalanan
Rekap perjalanan dan grafik hari-hari kamu paling sering naik kereta. Riwayat disimpan di ponselmu.

Akun dan privasi
Kamu perlu mendaftar dengan email untuk memakai aplikasi. Akun bisa dihapus kapan saja lewat Profil, Hapus akun, dan semua datanya ikut terhapus. Lokasi hanya dipakai saat perjalanan aktif dan izinnya diminta bertahap, dengan penjelasan sebelum dialog Android muncul. Tidak ada iklan dan tidak ada pelacak analitik pihak ketiga. Aplikasi gratis.

Teman Kereta adalah aplikasi independen dan bukan aplikasi resmi PT Kereta Commuter Indonesia. Data jadwal berasal dari sumber data yang tersedia dan bisa berbeda dari kondisi di lapangan.
```

Baris terakhir (disclaimer independen) **penting**: Play menolak app yang tampak mewakili operator resmi, dan
ini melindungi dari klaim peniruan identitas.

**Kategori**: Maps & Navigation (alternatif: Travel & Local). **Tag**: transportasi umum, jadwal.

**Kontak**: email aktif (lihat 0.4), situs `https://temankereta.web.id`.

---

## 7. Aset grafis

| Aset | Syarat Play | Status |
|---|---|---|
| Ikon app | PNG 512×512 | **Siap**: `docs/play-store/assets/icon-512.png` (dari `assets/branding/tk_icon.png`) |
| Feature graphic | 1024×500 | **Draf siap**: `docs/play-store/assets/feature-graphic-1024x500.png` — silakan ganti jika ada desain sendiri |
| Screenshot ponsel | 2–8 gambar, sisi 320–3840 px, rasio maks. 2:1 | **Belum ada.** Harus screenshot app asli dari ponsel/emulator (jangan mockup agar tidak dianggap menyesatkan). Saran 6 layar: Beranda, Jadwal, Peta posisi kereta, Alarm stasiun, Tempat sekitar stasiun, Forum. |
| Screenshot tablet 7"/10" | Opsional | Lewati |

Folder `marketing/promo/` berisi slide 1200×1600 (rasio 3:4) yang bisa dipakai sebagai gambar promosi, tetapi
bukan screenshot app, jadi jangan diunggah sebagai screenshot.

---

## 8. Urutan kerja yang disarankan

1. Ganti password database yang bocor di repo (0.5).
2. Putuskan: tambah hapus akun + laporan forum sekarang (build 1.0.16+17), atau rilis 1.0.15 dengan risiko
   ditolak. Saya sarankan yang pertama.
3. Perbarui dan deploy kebijakan privasi; pastikan email kontak aktif.
4. Ambil 6 screenshot dan rekam video demo lokasi.
5. Isi App content, Data safety, Store listing; unggah AAB ke **Internal testing** dulu.
6. Cek pre-launch report, lalu promosikan ke Production.
