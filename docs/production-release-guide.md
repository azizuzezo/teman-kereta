# Panduan Rilis Produksi Teman Kereta (Production Launch Guide)

Dokumen ini berisi panduan teknis langkah demi langkah untuk melakukan penggelaran (deployment) aplikasi **Teman Kereta** secara live ke server cloud, web, dan Google Play Store.

---

## 1. 🗄️ Deployment Database (Supabase Cloud)

1. **Buat Proyek di Supabase Cloud:**
   - Buka [https://supabase.com](https://supabase.com) dan buat proyek baru (misal nama proyek: `teman-kereta-prod`).
   - Salin **Project URL** (`https://<project-id>.supabase.co`) dan **Anon Key** dari menu *Settings -> API*.

2. **Deploy Migrasi SQL:**
   - Buka terminal di folder utama proyek `Teman Kereta`.
   - Jalankan perintah berikut untuk mengunggah 12 migrasi database secara otomatis:
     ```bash
     npx supabase link --project-ref <project-id>
     npx supabase db push
     ```

3. **Konfigurasi Auth pada Supabase Dashboard:**
   - **Authentication -> URL Configuration:**
     - **Site URL**: `https://temankereta.id` (atau URL domain web publik Anda).
     - **Redirect URLs**: Tambahkan:
       - `temankereta://login-callback`
       - `https://temankereta.id/*`
       - `https://admin.temankereta.id/*`
   - **Authentication -> Email Templates -> Confirm Signup:**
     - Ubah **Sender Name** menjadi `Teman Kereta`.
     - (Opsional) Hubungkan **Custom SMTP** (seperti Resend, SendGrid, atau AWS SES) di menu *Settings -> Auth -> SMTP Settings* agar email konfirmasi dikirim menggunakan domain email resmi (`no-reply@temankereta.id`).

---

## 2. 🌐 Deployment Web Admin & Landing Page (Cloudflare)

Ada dua situs terpisah, dua deploy target terpisah:

- **Admin panel** (`admin/`, Next.js via OpenNext) → Cloudflare **Worker**,
  domain `https://panel.temankereta.web.id` — sengaja subdomain tersembunyi,
  tidak ditautkan dari mana pun.
- **Landing page** (`landing_page/`, HTML statis) → Cloudflare **Pages**,
  domain `https://temankereta.web.id`.

### Update admin panel (setiap ada perubahan kode di `admin/`)
```bash
cd admin
npm run deploy
```
Ini otomatis build (`opennextjs-cloudflare build`) lalu deploy ke Worker
`temankereta-admin`. Domain custom (`panel.temankereta.web.id`) sudah
terpasang di `wrangler.jsonc` — tidak perlu setup ulang tiap deploy.

**Kalau menambah environment variable baru yang sifatnya rahasia** (service
role key, API key pihak ketiga, dll) — itu tidak ikut ter-deploy otomatis
dari `.env.local`. Set manual sekali via:
```bash
cd admin
npx wrangler secret put NAMA_SECRET
```
(akan diminta memasukkan nilainya secara interaktif — jangan taruh langsung
di command).

### Update landing page (setiap ada perubahan file di `landing_page/`)
```bash
cd landing_page
npx wrangler pages deploy . --project-name temankereta-landing --branch main
```
Custom domain (`temankereta.web.id` + `www.`) diatur sekali lewat dashboard
Cloudflare (Workers & Pages → `temankereta-landing` → Custom domains) — tidak
perlu diulang tiap deploy.

**Catatan file besar**: Cloudflare Pages menolak file di atas 25 MB per
berkas. Jangan taruh APK langsung di `landing_page/assets/` — tombol unduh di
landing page sudah otomatis mengambil rilis terbaru dari tabel
`app_releases` (lihat Bagian 3), jadi tidak perlu di-bundle manual.

---

## 3. 📱 Build & Rilis Aplikasi Android (Sideload APK)

Teman Kereta didistribusikan sebagai APK sideload (bukan lewat Google Play
Store). File APK di-hosting di **Cloudflare R2** (bucket
`temankereta-releases`, custom domain `dl.temankereta.web.id`) — **bukan**
Supabase Storage, karena Supabase membatasi ukuran upload ke 50MB per
proyek (dan menaikkannya lewat CLI diblokir oleh fitur tak terkait yang
butuh paket berbayar), sementara build APK app ini sudah rutin di atas
50MB. R2's shared `*.r2.dev` juga sempat dicoba dan ternyata diblokir ISP
untuk sejumlah pengguna nyata — makanya dipasangi custom domain sendiri.
Aplikasi mobile memeriksa tabel `app_releases` saat dibuka (dan saat
resume dari background) untuk mengetahui apakah ada versi baru.

### Cara publish (satu perintah, otomatis)

1. **Naikkan versi** di `pubspec.yaml`:
   ```yaml
   version: 1.0.2+3   # format: nama_versi+kode_versi, kode_versi harus naik tiap rilis
   ```
2. **Jalankan skrip build + publish:**
   ```powershell
   .\scripts\build-release.ps1 -Changelog "Ringkasan perubahan untuk rilis ini"
   ```
   Skrip ini otomatis: build APK (arm64, release) → upload ke R2
   (`dl.temankereta.web.id`) → **verifikasi link benar-benar bisa diakses
   (HTTP 200) sebelum lanjut** → insert/update baris `app_releases` →
   broadcast push notification ke semua device terdaftar. Kalau upload
   gagal atau link tidak bisa diakses, skrip berhenti tanpa mempublish apa
   pun (mencegah link rusak sampai ke pengguna).
   - Tambahkan `-MinSupportedVersionCode <N>` kalau rilis ini krusial dan
     versi lama harus dipaksa update.
   - Tambahkan `-SkipPublish` untuk build APK saja tanpa publish (mis. buat
     sekadar dites lokal dulu).

### Cara publish manual (fallback, hanya untuk APK di bawah 50MB)

Halaman admin panel `/releases` masih ada dan tetap berfungsi untuk upload
manual, tapi uploadnya lewat Supabase Storage — akan gagal (403/413) untuk
APK di atas 50MB. Gunakan skrip di atas untuk kondisi normal.

---

## 3b. 📣 Auto-post ke Threads (opsional)

Thread forum yang mulai ramai diposting otomatis ke akun Threads milik Teman
Kereta. Hanya memposting ke feed akun sendiri — tidak ada jalur untuk
berkomentar di thread orang lain.

**Pengumuman rilis TIDAK otomatis.** Cron tidak pernah mengumumkan versi baru
dengan sendirinya; itu selalu keputusan manual. Untuk mengumumkan rilis:

```bash
KEY=$(grep -m1 '^SUPABASE_SERVICE_ROLE_KEY=' admin/.env.local | cut -d= -f2-)

# versi terbaru (maks 3 hari terakhir)
curl -X POST "https://<ref>.supabase.co/functions/v1/post-to-threads" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"include_releases":true}'

# satu versi tertentu, tanpa batas umur
curl -X POST "https://<ref>.supabase.co/functions/v1/post-to-threads" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"release_id":"<uuid app_releases>"}'
```

Changelog dari `app_releases.changelog` otomatis ikut di badan post-nya.

Komponennya:
- `supabase/migrations/20260906090000_threads_auto_post.sql` — tabel
  `social_accounts` + `social_post_log`, dan cron tiap 15 menit.
- `supabase/functions/post-to-threads/index.ts` — pemilih konten + pemanggil
  Threads API.
- `admin/scripts/threads-connect.mjs` — penghubung akun, dijalankan sekali.

### Pemasangan pertama kali

Di dashboard Meta (<https://developers.facebook.com>, app kamu -> Threads API)
pastikan dulu tiga hal:

- Izin `threads_basic` + `threads_content_publish` aktif.
- **Redirect callback URL** diisi persis `https://temankereta.web.id/threads-callback`
  (halamannya ada di `landing_page/threads-callback/`, tugasnya cuma
  menampilkan `code` agar gampang disalin).
- **Uninstall / Deauthorize callback URL** dan **Delete callback URL** —
  Meta mewajibkan keduanya. Isi dengan:

  ```
  https://<project-ref>.supabase.co/functions/v1/threads-callbacks/deauthorize
  https://<project-ref>.supabase.co/functions/v1/threads-callbacks/data-deletion
  ```

  Keduanya dilayani satu Edge Function, `supabase/functions/threads-callbacks/`.
  Deploy fungsi itu **sebelum** menyimpan form-nya — Meta memanggil URL-nya
  untuk memverifikasi saat disimpan.
- Akun Threads-mu terdaftar sebagai **Threads Tester**, dan undangannya sudah
  diterima lewat aplikasi Threads (Settings -> Website permissions -> Invites).

```bash
# 1. Simpan App ID + Secret ke admin/.env.local
#    THREADS_APP_ID=...
#    THREADS_APP_SECRET=...

# 2. Simpan kredensial pemanggil ke Vault (lewat SQL editor Supabase)
#    select vault.create_secret('https://<ref>.supabase.co/functions/v1/post-to-threads', 'threads_autopost_url');
#    select vault.create_secret('<SERVICE_ROLE_KEY>', 'threads_autopost_key');

# 3. Deploy kedua Edge Function
supabase secrets set PUBLIC_SITE_URL=https://temankereta.web.id
supabase secrets set THREADS_APP_SECRET=...
supabase functions deploy post-to-threads
supabase functions deploy threads-callbacks --no-verify-jwt

# 4. Ambil URL otorisasi, buka di browser, setujui izinnya
cd admin && node scripts/threads-connect.mjs --url

# 5. Tukar code dari halaman callback jadi token 60 hari + simpan
node scripts/threads-connect.mjs --code <CODE>

# 6. Uji sekali tanpa menunggu cron
curl -X POST "$SUPABASE_URL/functions/v1/post-to-threads" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY"
```

Halaman callback ikut ter-deploy bersama landing page
(`npx wrangler pages deploy .`), jadi deploy landing page dulu sebelum
langkah 4.

### Mematikan sementara

```sql
update public.social_accounts set enabled = false where platform = 'threads';
```

### Ambang penyaringan

Thread forum baru diposting kalau `like_count >= 5`, umurnya di bawah 48 jam,
dan isinya tidak memuat tautan keluar. Maksimal 2 post per 15 menit (plafon
Threads sendiri 250 post / 24 jam). Semua angka ini konstanta di bagian atas
`supabase/functions/post-to-threads/index.ts`.

---

## 4. 🏁 Pengujian Akhir Setelah Rilis

- **Tes Pendaftaran User:** Buat akun di aplikasi mobile -> Periksa email konfirmasi -> Klik link -> Buka aplikasi.
- **Tes Rute & Peta:** Buka peta KRL -> Pastikan rute & daftar stasiun memuat data dengan lancar.
- **Tes Web Admin:** Login ke web admin dengan akun terdaftar di `admin_users` -> Kelola data stasiun/layanan.
