# GTFS GAPEKA 2026 — Sumatera Bagian Selatan

Feed GTFS statis hasil konversi dari dokumen resmi Grafik Perjalanan Kereta Api (GAPEKA) 2026 Direktorat Jenderal Perkeretaapian, Kementerian Perhubungan. Belum diimpor ke database.

## Sumber

- Dokumen: **KP-DJKA 119 Tahun 2026 (tanggal 30 Oktober 2026)** tentang Grafik Perjalanan Kereta Api pada Jaringan Jalur Kereta Api Nasional di Sumatera Bagian Selatan Tahun 2026
- URL: https://djka.kemenhub.go.id/uploads/202611/KP%20DJKA%20119%20TAHUN%202026%20GAPEKA%20SUMBAGSEL.pdf
- Berlaku mulai: **1 Desember 2026** (tertulis "Berlaku Mulai Tanggal 01 Desember 2026" di setiap Daftar Waktu).
- Bagian yang dipakai: Lampiran II "Buku Perjalanan Kereta Api" (tabel per KA: stasiun, datang, berangkat; halaman PDF 15–223 dari 304) dan Lampiran IV "Buku Penomoran Kereta Api" (daftar nomor KA per kelas, REGULER/FAKULTATIF, penyelenggara sarana) untuk kelas, status fakultatif, dan cek jumlah.

## Periode layanan (calendar.txt)

- `start_date` = 20261201. `end_date` = **20271231** (dipilih sendiri: dokumen tidak menyebut tanggal akhir; GAPEKA berlaku sampai diganti GAPEKA berikutnya). Perpanjang/perpendek bila GAPEKA baru terbit.
- PDF tidak mencantumkan pola hari (Senin–Minggu) untuk KA mana pun, jadi semua layanan dimodelkan **harian**.
- Tidak ada KA penumpang berstatus FAKULTATIF di feed ini.

## Metode parsing

1. `pdftotext -layout` (poppler) atas PDF asli. Halaman tabel berupa teks (bukan hasil scan), jadi tidak ada OCR.
2. Setiap tabel dimulai dengan judul `KA <nomor> (<nama>) Relasi|Lintas Pelayanan <asal> - <tujuan>`; baris stasiun berformat `No | Stasiun (KODE) | Kecepatan | Datang | Berangkat | Keterangan`. Tabel yang berlanjut ke halaman berikutnya digabung dan nomor urut barisnya dicek berurutan.
3. Arti kolom: `Ls` = langsung (tidak berhenti), dibuang dari stop_times. Waktu Datang & Berangkat = berhenti. `-` di asal/tujuan = waktu datang/berangkat disamakan dengan satu-satunya waktu yang ada. `Berh` / `Sb` = berhenti tetapi waktunya tidak dicantumkan di PDF (lihat Keterbatasan).
4. Lewat tengah malam: waktu dihitung berurutan termasuk waktu lintas `Ls`; bila waktu turun lebih dari 12 jam dianggap ganti hari dan ditambah 24 jam (mis. 25:51:00), tidak pernah direset ke 00:xx. Penurunan waktu yang lebih kecil dianggap ambigu (tidak ada yang ditemukan).
5. Kelas, status REGULER/FAKULTATIF, nama KA, dan agency diambil dari Buku Penomoran (kolom "Penyelenggara Sarana": PT. KAI -> `KAI`, PT. KCI -> `KCI`).
6. KA yang di Buku Penomoran tercatat sebagai satu perjalanan dengan beberapa nomor (mis. `42-43`, `801-802`) diberi `block_id` yang sama. Bila nomor lanjutan berangkat setelah tengah malam, waktunya ditambah 24 jam agar berurutan dalam satu hari layanan. `trip_headsign` = stasiun akhir seluruh perjalanan (blok), bukan stasiun akhir nomor KA itu saja.
7. ID: `trip_id` = `<prefix>_<nomor KA>`, `trip_short_name` = nomor KA, `route_id` per nama KA, `stop_id` = kode stasiun resmi di PDF.

## Ringkasan isi

- Trip (nomor KA penumpang): **10**; rute (nama KA): 4; stasiun: 41; baris stop_times: 154 (di antaranya 0 halte tanpa waktu, di 0 trip); block_id: 0.

| Kelas (Buku Penomoran) | Trip | di antaranya fakultatif |
|---|---:|---:|
| EKSEKUTIF BISNIS | 2 | 0 |
| EKONOMI | 8 | 0 |

Catatan: Lampiran IV menghitung per *perjalanan* (nomor gabungan seperti `42-43` dihitung satu), feed ini menghitung per nomor KA.

## Validasi

Dicek dengan skrip: setiap trip ≥ 2 halte; waktu tidak pernah turun; halte awal/akhir punya waktu; setiap stop_id ada di stops.txt; tidak ada trip_id ganda; referensi route/service valid; tanpa BOM; block tidak tumpang tindih; himpunan nomor KA penumpang di Buku Penomoran = himpunan trip_short_name; status fakultatif cocok. Hasil:

```
== sumbagsel
  agency.txt: 1 baris
  routes.txt: 4 baris
  trips.txt: 10 baris
  stop_times.txt: 154 baris
  stops.txt: 41 baris
  calendar.txt: 1 baris
  feed_info.txt: 1 baris
  nilai waktu >= 24:00:00: 9
  block_id: 0
  Rekap per kelas (Lampiran IV: tertulis REG/FAK | terhitung REG/FAK | jumlah nomor KA = trip):
   OK EKSEKUTIF BISNIS                 2/0 | 2/0 | 2 nomor KA -> 2 trip
   OK EKONOMI                          8/0 | 8/0 | 8 nomor KA -> 8 trip
  ERRORS: 0
```

## Baris yang dilewati

KA non-penumpang tidak dimasukkan. Jumlah nomor KA dengan tabel di Lampiran II yang dilewati:

- BARANG BATUBARA TARAHAN ISI: 52
- BARANG BATUBARA TARAHAN KOSONG: 52
- BARANG BATUBARA KERTAPATI ISI: 16
- BARANG BATUBARA KERTAPATI KOSONG: 16
- BARANG BATUBARA SWASTA ISI: 28
- BARANG BATUBARA SWASTA KOSONG: 28
- BARANG BATUBARA SWITCHING (ISI): 12
- BARANG BATUBARA SWITCHING (KOSONG): 12
- BARANG BBM: 6
- BARANG SEMEN: 4
- BARANG PULP: 8

KA dinas (perjalanan kosongan rangkaian/lokomotif) hanya tercantum di Buku Penomoran, tanpa tabel waktu di Lampiran II, dan tidak dimasukkan (jumlah perjalanan tertulis, REGULER/FAKULTATIF):
- DINAS LOKOMOTIF: 70/4

Lampiran II tidak memuat tabel KA Luar Biasa (KLB) atau kosongan selain yang disebut di atas. Baris ambigu/tidak terbaca: tidak ada.

## Koordinat stasiun

Koordinat hanya diambil dari data yang sudah ada di repo, tidak ada yang dikarang. Urutan prioritas: `supabase/data/gtfs-krl-yogyakarta/stops.txt`, `temp_gtfs/stops.txt` (sebagian besar stop di sini tidak berkoordinat sehingga tidak terpakai), lalu `supabase/data/gtfs-antarkota/candidates/stations_osm_candidates.csv` (cocok kode; bila satu kode punya beberapa baris, dipilih yang namanya cocok). Jika kode tidak ada, dipakai baris OSM yang **namanya** cocok persis dan unik (bukan stasiun kereta cepat).

Sumber per stasiun: stations_osm_candidates.csv: 41.

Kode cocok tetapi nama berbeda (dianggap stasiun yang sama; `stop_name` memakai nama dari sumber koordinat):
- BIB: PDF "Blimbing Pendopo" / sumber "Belimbing Pendopo"
- LAR: PDF "Labuan Ratu" / sumber "Labuhanratu"

Stasiun yang di `station_review.json` masih berstatus perlu ditinjau (koordinat tetap dipakai):
- MSL Muara Saling: needs_review — OSM 21 m / Wikidata 12 m from track; sources differ 402 m
- NRR Negara Ratu: single_source_on_track
- PGG Pagergunung: single_source_on_track
- WAY Waytuba: single_source_on_track

### Stasiun tanpa koordinat

Tidak ada: semua stasiun tempat KA penumpang berhenti mendapat koordinat dari sumber di atas.

## Keterbatasan

- GAPEKA mencatat semua pemberhentian, termasuk pemberhentian operasional (persilangan/penyusulan, ganti awak). PDF tidak membedakan mana yang melayani naik/turun penumpang, jadi semua halte diberi `pickup_type=0`/`drop_off_type=0`.
- Nama KA mengikuti dokumen (mis. "Anggrek" untuk Argo Bromo Anggrek, "Exspres Rajabasa", "Gajayana Fakultatif"). Nama stasiun mengikuti sumber koordinat.
- Kelas di `route_desc` adalah kelas GAPEKA, bukan kelas kereta/tiket. Satu nama KA bisa punya beberapa kelas (mis. Ambarawa).
- Hanya jadwal dasar GAPEKA; perubahan operasional KAI setelah terbit (KA tambahan, pembatalan, mutasi jadwal) tidak tercakup.
- `route_color` tidak diisi (PDF tidak memuat warna).
