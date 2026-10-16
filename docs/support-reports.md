# Laporan masalah dari aplikasi

Status: ditulis, **belum diterapkan/di-deploy**. Migrasi SQL belum dijalankan di database mana pun dan Edge Function belum di-deploy. Urutan pasang ada di bagian "Pasang".

## Alur

1. Pengguna membuka Profil, Bantuan atau Tentang, lalu "Laporkan masalah" (`/report`).
2. Aplikasi menyusun laporan: kategori, pesan, email kontak (hanya kalau dicentang), info perangkat dan aplikasi, serta log aplikasi (saklar "Sertakan log aplikasi", aktif secara bawaan). Isi persisnya bisa dilihat di "Log yang ikut terkirim" sebelum kirim.
3. Aplikasi `INSERT` satu baris ke `public.app_reports` dengan anon/user key. `id` dibuat di klien (uuid v4); 8 karakter pertama huruf besar adalah **nomor laporan** (`#3F2B8C1E`) yang ditampilkan ke pengguna.
4. Trigger `app_reports_notify_email` menembak Edge Function `send-report-email` lewat `pg_net`. Fungsi membaca baris itu dengan service role, mengirim email ke `SUPPORT_EMAIL` lewat Cloudflare Email Service, lalu mengisi `email_status`, `email_sent_at`, `email_error`.
5. Kalau tidak ada koneksi atau server menolak, laporan disimpan di perangkat (`<documents>/pending_reports/<id>.json`) dan dicoba lagi otomatis setiap halaman laporan dibuka. Pengguna juga bisa menekan "Kirim lewat email": berkas `.txt` laporan dibagikan lewat share sheet ke aplikasi email (cadangan `mailto:` tanpa lampiran bila share gagal). Karena `id` sama dipakai ulang, percobaan ulang tidak pernah membuat baris ganda.

## Kenapa tabel baru (`app_reports`), bukan `user_reports`

`public.user_reports` adalah laporan kondisi kereta/stasiun dari komunitas: `report_type` enum (kepadatan, AC, lift...), `line_id/station_id/trip_id`, `expires_at` default 6 jam, `user_id NOT NULL`, dan dimoderasi di halaman admin `/user-reports`. Laporan masalah aplikasi bukan konten komunitas, tidak boleh kedaluwarsa, bisa dikirim tanpa akun, dan membawa log hingga 200 KB. Aplikasi saat ini juga tidak menulis ke `user_reports` (hanya tabel Drift lokal). Memaksakan keduanya dalam satu tabel akan mencemari halaman moderasi.

## Bentuk tabel `public.app_reports` (untuk log viewer di admin)

Dibaca admin lewat service role (RLS dilewati). Klien hanya boleh `INSERT`.

| Kolom | Tipe | Isi |
|---|---|---|
| `id` | uuid PK | dibuat klien; nomor laporan = 8 karakter pertama, huruf besar |
| `user_id` | uuid null | `auth.uid()` otomatis; null bila tidak masuk. FK ke `users`, `on delete cascade` |
| `category` | text | `schedule`, `notification`, `map`, `forum`, `account`, `other` |
| `message` | text | 10 sampai 4000 karakter |
| `contact_email` | text null | hanya bila pengguna mencentang "sertakan email untuk dihubungi" |
| `app_version`, `build_number`, `platform`, `os_version`, `device_model` | text null | ringkasan cepat untuk daftar/filter |
| `diagnostics` | jsonb | `{format, generated_at, app{...}, device{...}, status{...}, log{included,line_count}}` (lihat `DiagnosticsFormatter.toJson`) |
| `log_text` | text null | log yang sudah disamarkan; maksimum 200 000 karakter (check constraint); null bila saklar log dimatikan |
| `status` | text | `open` (bawaan), `in_progress`, `resolved`, `dismissed`; diubah admin |
| `email_status` | text | `pending`, `sent`, `failed` |
| `email_sent_at`, `email_error`, `email_attempts` | | hasil pengiriman email |
| `created_at`, `updated_at` | timestamptz | |

Indeks: `created_at desc`, `(user_id, created_at desc)`, dan backlog email (`email_status <> 'sent'`). Batas laju di trigger: 10 laporan per akun per jam, 30 laporan anonim per jam untuk seluruh proyek (error `54000`).

Saran untuk log viewer: daftar dari `created_at desc` dengan kolom nomor laporan, kategori, versi, perangkat, `email_status`; detail menampilkan `message`, `diagnostics` dan `log_text` dalam `<pre>`; aksi ubah `status`. Jangan tampilkan `contact_email` ke peran yang tidak perlu.

## Format log dan laporan

Header tetap `=== TEMAN KERETA LAPORAN ===`, bagian `[Ringkasan]`, `Pesan:`, `[Perangkat]`, `[Aplikasi]`, `[Status]`, `[Log terbaru]`, penutup `=== AKHIR LAPORAN ===`. Implementasi: `lib/core/diagnostics/diagnostics_report.dart` (app) dan `supabase/functions/send-report-email/format.ts` (email, tata letak sama).

Baris log: `2026-10-15T10:22:11.034+07:00 E [tag] pesan` (ISO-8601 dengan zona waktu; huruf level D/I/W/E).

Sumber log (`lib/core/diagnostics/app_log.dart`, dipasang di `main()`): `debugPrint`, `FlutterError.onError`, `PlatformDispatcher.onError`, dan `AppLog.i/w/e/d(tag, pesan)`. Ring buffer 400 entri di memori, dicerminkan ke `<documents>/logs/app_log.txt` (2 berkas bergantian, 256 KB masing-masing, jadi sekitar 512 KB). Handler lama (Sentry bila aktif) tetap dipanggil. Baris sesi sebelumnya (mis. sebelum crash) ikut dengan pembatas `--- sesi sebelumnya ---`.

Penyamaran sebelum masuk buffer (`log_redactor.dart`, diuji): JWT, `Bearer ...`, pasangan `apikey/token/password/secret/authorization`, email, nomor telepon, dan koordinat dibulatkan ke 2 desimal (sekitar 1 km). Laporan membawa paling banyak 300 baris dan 150 KB (baris terbaru yang dipertahankan).

Yang **tidak** ikut: kata sandi, email akun (kecuali dicentang), token, posisi GPS presisi, isi forum.

## Pasang (urutan)

1. **Domain pengirim di Cloudflare.** Dashboard Cloudflare: Compute, Email Service, Email Sending, "Onboard Domain", pilih `temankereta.web.id`. Cloudflare menambahkan sendiri record DNS di subdomain `cf-bounce` (MX, SPF, DKIM) dan `_dmarc`; domain harus memakai DNS Cloudflare. Perubahan biasanya 5 sampai 15 menit, bisa sampai 24 jam. Cek: `npx wrangler email sending list`.
2. **API token.** Buat token dengan izin Email Sending (Edit) untuk akun itu. Catat Account ID.
3. **Secret Edge Function** (jangan masuk repo):
   ```
   supabase secrets set CLOUDFLARE_ACCOUNT_ID=<id akun> \
     CLOUDFLARE_API_TOKEN=<token> \
     SUPPORT_EMAIL=support@temankereta.web.id \
     WEBHOOK_SECRET=<string acak panjang, mis. openssl rand -hex 32>
   # opsional, bawaan laporan@temankereta.web.id (domainnya harus sudah di-onboard):
   supabase secrets set EMAIL_FROM=laporan@temankereta.web.id
   ```
4. **Deploy:** `supabase functions deploy send-report-email`.
5. **Terapkan migrasi** `supabase/migrations/20261016090000_app_reports.sql` (`supabase db push`).
6. **Vault** (jalankan di SQL editor; `WEBHOOK_SECRET` harus sama dengan langkah 3):
   ```sql
   select vault.create_secret('https://<project-ref>.supabase.co/functions/v1/send-report-email', 'app_report_email_url');
   select vault.create_secret('<WEBHOOK_SECRET>', 'app_report_email_secret');
   select vault.create_secret('<ANON_KEY>', 'app_report_email_jwt');
   ```
   Sampai Vault terisi, laporan tetap tersimpan dengan `email_status = 'pending'`.
7. Pastikan kotak masuk `support@temankereta.web.id` benar-benar menerima email (lewat Email Routing atau penyedia email yang ada).
8. Opsional: jadwalkan kirim ulang yang gagal tiap 10 menit:
   ```sql
   select cron.schedule('resend-app-report-emails', '*/10 * * * *',
     $$select public.resend_pending_app_report_emails(20)$$);
   ```

Variabel yang dipakai fungsi: `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN`, `SUPPORT_EMAIL`, `WEBHOOK_SECRET`, `EMAIL_FROM` (opsional). `SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY` disediakan Supabase.

## API Cloudflare yang dipakai

`POST https://api.cloudflare.com/client/v4/accounts/{account_id}/email/sending/send`, header `Authorization: Bearer <token>`. Body (nama kolom REST): `to`, `from` (string alamat), `subject`, `text`, `html`, `reply_to` (diisi bila pengirim melampirkan email), `attachments[{content (base64), filename, type, disposition}]`. Respons sukses `{success, result:{delivered, queued, permanent_bounces}}`; galat memakai `errors[{code,message}]`. Batas ukuran pesan total 5 MiB (kode 10200), laporan maksimum sekitar 200 KB. Fungsi mencoba ulang 3 kali (jeda 0,5 dan 1,5 detik) hanya untuk HTTP 429 dan 5xx. Referensi: developers.cloudflare.com/email-service/api/send-emails/rest-api/ (dicek saat penulisan; cek lagi bila API berubah).

## Mencoba setelah dipasang

1. Di aplikasi: Bantuan, Laporkan masalah, isi, kirim. Layar sukses menampilkan nomor laporan.
2. `select id, email_status, email_error from public.app_reports order by created_at desc limit 5;` harus berubah dari `pending` ke `sent` dalam beberapa detik, dan email `[Laporan #XXXXXXXX] ...` masuk dengan lampiran `log-XXXXXXXX.txt`.
3. Mode pesawat lalu kirim: layar "Laporan belum terkirim" muncul, laporan masuk antrean; nyalakan koneksi, buka ulang halaman laporan, baris muncul di tabel.
4. Kirim ulang manual satu laporan: `curl -X POST <url fungsi> -H "Authorization: Bearer <anon>" -H "x-webhook-secret: <secret>" -H "Content-Type: application/json" -d '{"id":"<uuid>"}'`.

Tes otomatis: `flutter test test/core/diagnostics test/features/support` dan `node --experimental-strip-types --test supabase/functions/send-report-email/format_test.ts` (atau `deno test`).

## Privasi dan keputusan yang masih terbuka

- Halaman Privasi di aplikasi sudah menyebut laporan masalah. **Kebijakan di situs (`temankereta.web.id/privacy`) belum**: tambahkan bahwa laporan berisi pesan, info perangkat/aplikasi, log yang disamarkan, email bila dicentang, disimpan di Supabase dan diteruskan ke `support@temankereta.web.id` lewat Cloudflare Email Service (pemroses data baru), dan form Data Safety Play Console perlu mencantumkan "diagnostics/crash logs".
- Retensi belum ditentukan. Laporan akun ikut terhapus saat akun dihapus; laporan tanpa akun dan salinan email di kotak masuk support dihapus manual. Tetapkan masa simpan (mis. 12 bulan) bila perlu, lalu jadwalkan `delete from public.app_reports where created_at < now() - interval '12 months'`.
- Pembatas laju anonim bersifat global, bukan per pengguna (tidak ada identitas tepercaya tanpa akun). Aplikasi ini mewajibkan akun, jadi jalur anonim jarang terpakai.
- Lampiran tangkapan layar tidak dibuat (butuh bucket Storage dan penyamaran EXIF); tidak ada tombolnya di aplikasi.
