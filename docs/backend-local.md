# Backend Supabase lokal

Dokumen ini menjelaskan stack Supabase **lokal** (`npx supabase start`) yang tetap menjadi cara utama untuk pengembangan sehari-hari — konfigurasi `supabase/config.toml` di repo ini sengaja tidak berisi `project_ref`, blok `[remotes]`, atau workflow deployment.

**Catatan (2026-08-05)**: proyek ini sekarang juga terhubung ke sebuah project Supabase hosted nyata (lihat `ENGINEERING.md`'s bagian "Hosted Supabase project") — ini adalah keputusan sadar dari pengguna, bukan pelanggaran aturan di bawah. Aturan "jangan `supabase link`/`db push`" di bawah tetap berlaku untuk menjaga stack **lokal** ini tetap murni lokal; itu tidak melarang menunjuk `.env` root ke project hosted secara terpisah, atau menjalankan `supabase db push --db-url` secara eksplisit terhadap project hosted itu ketika memang diminta.

## Prasyarat

- Docker Desktop aktif.
- Node.js tersedia untuk menjalankan Supabase CLI melalui `npx` (atau pasang CLI dengan metode resmi lain).

## Menjalankan stack lokal

Dari root proyek:

```powershell
npx supabase start
```

Saat pertama kali dijalankan, CLI membuat container lokal, menerapkan semua file di `supabase/migrations`, lalu menjalankan `supabase/seed.sql`. Seed ditandai **DATA DEMO** dan bukan data operasional.

Endpoint standar konfigurasi ini:

- API lokal: `http://127.0.0.1:54321`
- PostgreSQL lokal: `postgresql://postgres:postgres@127.0.0.1:54322/postgres`
- Supabase Studio: `http://127.0.0.1:54323`
- Inbucket (email uji): `http://127.0.0.1:54324`

Ambil URL dan key lokal yang benar dari output berikut, lalu simpan hanya sebagai konfigurasi development:

```powershell
npx supabase status
```

Untuk menerapkan ulang migrasi dan seed ke database lokal:

```powershell
npx supabase db reset --local
```

Untuk menghentikan container lokal:

```powershell
npx supabase stop
```

## Batas aman lokal

- Jangan menjalankan `supabase link`.
- Jangan menambahkan blok `[remotes]` atau project reference hosted ke `config.toml`.
- Jangan menjalankan `supabase db push`, `supabase functions deploy`, atau perintah deployment lain.
- Gunakan `--local` secara eksplisit pada operasi database yang berpotensi ambigu.
- Secret produksi tidak boleh ditempatkan di repository atau aplikasi Flutter.

## Model akses

- Data transit, jadwal, posisi, gangguan, aturan transit, dan tempat terkurasi dapat dibaca oleh klien `anon` maupun `authenticated`.
- Penulisan data referensi/realtime tidak dibuka ke klien; proses ingest lokal menggunakan koneksi server atau `service_role` lokal.
- Favorit, rencana komuter, sesi perjalanan, token perangkat, preferensi, log notifikasi, dan laporan dilindungi RLS berdasarkan `auth.uid()`.
- Pengguna anonim Supabase tetap mendapat profil privat dan preferensi default, sehingga fitur sinkronisasi lokal dapat diuji tanpa login email.
- Laporan baru selalu berstatus `pending`; status moderasi hanya dapat diubah oleh proses server.

## Catatan waktu GTFS

Kolom `stop_times.scheduled_arrival` dan `scheduled_departure` menggunakan tipe PostgreSQL `interval`, bukan `time`. Ini disengaja agar nilai GTFS setelah tengah malam seperti `25:10:00` tidak kehilangan tanggal layanan asalnya. Timestamp aktual dihitung dari `trips.service_date + scheduled_*`.

## Memilih data provider (`TRANSIT_PROVIDER`)

`lib/data/providers/provider_registry.dart` memilih implementasi provider berdasarkan `AppEnvironment.provider` (env var `TRANSIT_PROVIDER`). Matriks fallback saat ini:

| Kemampuan | `mock` (default) | `gtfs` | `official_api` | `local_supabase` |
|---|---|---|---|---|
| Jadwal & pencarian trip | Data Demo | **GTFS statis (impor lokal)‡, hanya perjalanan langsung**, atau Data Demo sebelum diimpor | REST `/trips/search`, `/departures` | **Supabase nyata, hanya perjalanan langsung**† |
| Stasiun & tempat sekitar | Data Demo | **GTFS statis (impor lokal)‡** stasiun, tempat tetap Data Demo | REST `/stations`, `/places` | **Supabase nyata** |
| Posisi kereta / trip update / gangguan | Data Demo | **GTFS-Realtime resmi** (`GtfsRealtimeTransitProvider`) | REST `/vehicle-positions`, `/trip-updates`, `/service-alerts` | **Supabase Realtime nyata** (`.stream()`) |

‡ `GtfsStaticImporter` (`lib/data/providers/gtfs_static_importer.dart`) mengurai feed GTFS Schedule (static) — `.zip` mentah via `importZipBytes` atau berkas `.txt` yang sudah diekstrak via `importFiles` — dan menulisnya ke tabel Drift `GtfsStops`/`GtfsRoutes`/`GtfsTrips`/`GtfsStopTimes`/`GtfsCalendarEntries`/`GtfsCalendarDateEntries` (`lib/core/database/app_database.dart`). `GtfsStaticScheduleProvider` lalu membaca tabel-tabel itu, dengan resolusi hari-layanan penuh (calendar.txt + calendar_dates.txt, termasuk waktu lintas tengah malam seperti `25:10:00`) — **bukan stub**. Sama seperti `local_supabase`, `searchTrips` **hanya menemukan trip pada `trip_id` yang sama** (tidak ada router lintas-transit). Selama belum ada feed yang diimpor (`gtfsStopCount() == 0`), provider ini otomatis jatuh ke Data Demo, jadi `TRANSIT_PROVIDER=gtfs` tidak pernah menampilkan aplikasi kosong sebelum impor dijalankan. **Sudah ada UI dalam aplikasi untuk memicu impor** — Profil → "Impor jadwal GTFS" (`/settings/gtfs-import`), memakai `file_picker` untuk memilih `.zip` dari penyimpanan perangkat. Sudah diverifikasi nyata di emulator Android (lihat `ENGINEERING.md`'s bagian "In-app import UI").

† `local_supabase` (`lib/data/providers/supabase_transit_provider.dart`) membaca tabel nyata via fungsi SQL di `supabase/migrations/20260805090000_transit_query_functions.sql` (`get_station_departures`, `search_direct_trips`, `get_trip_stop_codes`). `search_direct_trips` **hanya menemukan trip yang melayani kedua stasiun pada `trip_id` yang sama** — tidak ada router lintas-transit; pasangan stasiun yang hanya terhubung lewat transit akan menghasilkan daftar kosong, bukan rute yang salah. **Sudah diverifikasi end-to-end (2026-08-05)** terhadap stack Supabase lokal yang benar-benar berjalan — lihat `ENGINEERING.md`'s bagian `local_supabase` untuk detail, termasuk uji integrasi opsional di `test/integration/supabase_transit_provider_live_test.dart`.

Untuk memakai `local_supabase`, set `SUPABASE_ENABLED=true` (di samping `TRANSIT_PROVIDER=local_supabase`) agar `main.dart` benar-benar memanggil `Supabase.initialize()` sebelum `runApp()` — tanpa itu, `supabaseTransitProvider` sengaja melempar `StateError` yang jelas alih-alih diam-diam jatuh ke provider lain.

Untuk mengaktifkan feed GTFS-Realtime resmi:

```
TRANSIT_PROVIDER=gtfs
GTFS_RT_VEHICLE_POSITIONS_URL=https://contoh-operator/gtfsrt/vehicle-positions.pb
GTFS_RT_TRIP_UPDATES_URL=https://contoh-operator/gtfsrt/trip-updates.pb
GTFS_RT_ALERTS_URL=https://contoh-operator/gtfsrt/alerts.pb
GTFS_RT_POLL_SECONDS=30
```

Ketiga URL boleh sama jika operator menerbitkan satu feed gabungan. Saat `APP_ENV=local`, `AppEnvironment.validateLocalOnly()` menolak URL non-localhost — set `APP_ENV` ke nilai lain untuk menunjuk feed publik sungguhan. Label kesegaran data (`DataFreshness`) dihitung ulang dari `recordedAt` setiap kali, termasuk saat feed gagal diambil, sehingga status tidak pernah "macet" di Real-time ketika feed sudah mati.

Untuk `official_api`, backend harus mengekspos endpoint JSON yang cocok dengan `fromJson` masing-masing model di `lib/domain/entities/transit_models.dart` (`Station`, `Departure`, `TransitTrip`, `VehiclePosition`, `ServiceAlert`, `NearbyPlace`) ditambah `TripUpdate` di `lib/domain/providers/transit_providers.dart`.
