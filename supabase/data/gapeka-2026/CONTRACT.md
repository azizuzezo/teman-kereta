# GAPEKA 2026: kontrak antar-bagian (A database, B importer, C feed, D aplikasi)

Disepakati 2026-11-18. Semua bagian menulis file saja: **tidak ada yang menyentuh database Supabase.**

## A. Skema dan RPC (file migrasi baru, tidak dijalankan)

- `public.stop_times.is_estimated boolean not null default false`: `true` = jam tidak tercetak di GAPEKA, diisi
  interpolasi (GTFS `timepoint=0`).
- `trips.service_id` sudah ada. Nilai `GJ26_FAKULTATIF` = KA fakultatif (Lampiran IV); `GJ26_HARIAN` = reguler.
- RPC menambah kolom keluaran (kolom lama tetap, nama dan urutan tidak berubah; kolom baru ditambah di akhir):
  - `get_station_departures`: `is_estimated boolean`, `service_id text`.
  - `search_direct_trips`: `origin_is_estimated boolean`, `destination_is_estimated boolean`, `service_id text`.
  - `search_one_transfer_trips`: `origin_is_estimated`, `transfer_arrival_is_estimated`,
    `transfer_departure_is_estimated`, `destination_is_estimated` (boolean), `first_service_id text`,
    `second_service_id text`.
  - `get_trip_stop_codes`: `scheduled_arrival interval`, `scheduled_departure interval`, `is_estimated boolean`.
- Aplikasi (D) wajib tetap jalan bila kolom baru belum ada (migrasi belum diterapkan): semua kolom baru dibaca
  sebagai opsional, default `false` / `null`.

## B. Importer

- Baca `timepoint` bila ada: `timepoint=0` -> `is_estimated=true`; kolom tidak ada atau `1` -> `false`.
- Skrip `admin/scripts/import-real-gtfs.mts`: opsi `--operator-map KAI=<uuid>,KCI=<uuid>` memetakan
  `routes.agency_id` ke operator; tanpa opsi itu perilaku lama (satu operator). `--respect-calendar` sudah ada.

## C. Feed siap-import (supabase/data/gapeka-2026/import/)

- Kode lintas baru: huruf besar, tanpa prefiks `GJ26_` (mis. `BST`, `YIA`, `BDR`). Kode lintas lama tidak berubah
  (BOGOR, CIKARANG, RANGKAS, TANGERANG, PRIOK, YKPL).
- `supabase/data/gapeka-2026/networks.json`: pembagian jaringan untuk aplikasi:
  `{"networks":[{"id":"jabodetabek","label":"Jabodetabek","lines":["BOGOR","CIKARANG",...]}, ...]}`.
  `id` dipakai sebagai nilai enum di Dart. Jaringan yang sudah ada: `jabodetabek`, `jogja`.

## D. Aplikasi

- Pembagian jaringan dibaca dari satu peta `kode lintas -> jaringan` di `lib/domain/usecases/transit_network.dart`
  (diisi dari `networks.json`), bukan lagi "selain YKPL = Jabodetabek".
- Jam `is_estimated` ditampilkan dengan tanda perkiraan; KA `GJ26_FAKULTATIF` diberi label "Fakultatif".
