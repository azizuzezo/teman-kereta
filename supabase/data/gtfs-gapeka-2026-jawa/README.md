# GTFS GAPEKA 2026 — Jawa

Feed GTFS statis hasil konversi dari dokumen resmi Grafik Perjalanan Kereta Api (GAPEKA) 2026 Direktorat Jenderal Perkeretaapian, Kementerian Perhubungan. Belum diimpor ke database.

## Sumber

- Dokumen: **KP-DJKA 116 Tahun 2026 (tanggal 30 Oktober 2026)** tentang Grafik Perjalanan Kereta Api pada Jaringan Jalur Kereta Api Nasional di Jawa Tahun 2026
- URL: https://djka.kemenhub.go.id/uploads/202611/KP%20DJKA%20116%20TAHUN%202026%20GAPEKA%20JAWA.pdf
- Berlaku mulai: **1 Desember 2026** (tertulis "Berlaku Mulai Tanggal 01 Desember 2026" di setiap Daftar Waktu).
- Bagian yang dipakai: Lampiran II "Buku Perjalanan Kereta Api" (tabel per KA: stasiun, datang, berangkat; halaman PDF 58–1673 dari 1887) dan Lampiran IV "Buku Penomoran Kereta Api" (daftar nomor KA per kelas, REGULER/FAKULTATIF, penyelenggara sarana) untuk kelas, status fakultatif, dan cek jumlah.

## Periode layanan (calendar.txt)

- `start_date` = 20261201. `end_date` = **20271231** (dipilih sendiri: dokumen tidak menyebut tanggal akhir; GAPEKA berlaku sampai diganti GAPEKA berikutnya). Perpanjang/perpendek bila GAPEKA baru terbit.
- PDF tidak mencantumkan pola hari (Senin–Minggu) untuk KA mana pun, jadi semua layanan dimodelkan **harian**.
- Ada dua service_id: `*_HARIAN` (KA REGULER) dan `*_FAKULTATIF` (KA berstatus FAKULTATIF di Buku Penomoran). Keduanya saat ini diisi setiap hari. KA fakultatif hanya dijalankan bila diperlukan, jadi **perlu keputusan**: biarkan tampil setiap hari, matikan (isi 0 untuk semua hari), atau tandai khusus di aplikasi.

## Metode parsing

1. `pdftotext -layout` (poppler) atas PDF asli. Halaman tabel berupa teks (bukan hasil scan), jadi tidak ada OCR.
2. Setiap tabel dimulai dengan judul `KA <nomor> (<nama>) Relasi|Lintas Pelayanan <asal> - <tujuan>`; baris stasiun berformat `No | Stasiun (KODE) | Kecepatan | Datang | Berangkat | Keterangan`. Tabel yang berlanjut ke halaman berikutnya digabung dan nomor urut barisnya dicek berurutan.
3. Arti kolom: `Ls` = langsung (tidak berhenti), dibuang dari stop_times. Waktu Datang & Berangkat = berhenti. `-` di asal/tujuan = waktu datang/berangkat disamakan dengan satu-satunya waktu yang ada. `Berh` / `Sb` = berhenti tetapi waktunya tidak dicantumkan di PDF (lihat Keterbatasan).
4. Lewat tengah malam: waktu dihitung berurutan termasuk waktu lintas `Ls`; bila waktu turun lebih dari 12 jam dianggap ganti hari dan ditambah 24 jam (mis. 25:51:00), tidak pernah direset ke 00:xx. Penurunan waktu yang lebih kecil dianggap ambigu (tidak ada yang ditemukan).
5. Kelas, status REGULER/FAKULTATIF, nama KA, dan agency diambil dari Buku Penomoran (kolom "Penyelenggara Sarana": PT. KAI -> `KAI`, PT. KCI -> `KCI`).
6. KA yang di Buku Penomoran tercatat sebagai satu perjalanan dengan beberapa nomor (mis. `42-43`, `801-802`) diberi `block_id` yang sama. Bila nomor lanjutan berangkat setelah tengah malam, waktunya ditambah 24 jam agar berurutan dalam satu hari layanan (8 trip: KA 43, KA 69, KA 83, KA 93, KA 100, KA 98, KA 223F, KA 323). `trip_headsign` = stasiun akhir seluruh perjalanan (blok), bukan stasiun akhir nomor KA itu saja.
7. ID: `trip_id` = `<prefix>_<nomor KA>`, `trip_short_name` = nomor KA, `route_id` per nama KA, `stop_id` = kode stasiun resmi di PDF.

## Ringkasan isi

- Trip (nomor KA penumpang): **1967**; rute (nama KA): 113; stasiun: 355; baris stop_times: 26204 (di antaranya 9706 halte tanpa waktu, di 1276 trip); block_id: 235.

| Kelas (Buku Penomoran) | Trip | di antaranya fakultatif |
|---|---:|---:|
| ARGO | 36 | 0 |
| EKSEKUTIF | 48 | 14 |
| EKSEKUTIF CAMPURAN | 185 | 24 |
| EKONOMI JARAK JAUH | 50 | 4 |
| LOKAL EKONOMI | 174 | 0 |
| BANDARA YIA | 50 | 0 |
| BANDARA SMO | 10 | 0 |
| EKONOMI LOKAL (FEEDER) | 72 | 6 |
| COMMUTER LINE DAOP 6 YK | 34 | 7 |
| COMMUTER LINE BANDARA SOETTA | 140 | 12 |
| COMMUTER LINE DAOP 1 JAK | 1168 | 24 |

Catatan: Lampiran IV menghitung per *perjalanan* (nomor gabungan seperti `42-43` dihitung satu), feed ini menghitung per nomor KA.

## Validasi

Dicek dengan skrip: setiap trip ≥ 2 halte; waktu tidak pernah turun; halte awal/akhir punya waktu; setiap stop_id ada di stops.txt; tidak ada trip_id ganda; referensi route/service valid; tanpa BOM; block tidak tumpang tindih; himpunan nomor KA penumpang di Buku Penomoran = himpunan trip_short_name; status fakultatif cocok. Hasil:

```
== jawa
  agency.txt: 2 baris
  routes.txt: 113 baris
  trips.txt: 1967 baris
  stop_times.txt: 26204 baris
  stops.txt: 355 baris
  calendar.txt: 2 baris
  feed_info.txt: 1 baris
  nilai waktu >= 24:00:00: 1884
  block_id: 235
  Rekap per kelas (Lampiran IV: tertulis REG/FAK | terhitung REG/FAK | jumlah nomor KA = trip):
   OK ARGO                             36/0 | 36/0 | 36 nomor KA -> 36 trip
   OK EKSEKUTIF                        24/10 | 24/10 | 48 nomor KA -> 48 trip
   OK EKSEKUTIF CAMPURAN               132/18 | 132/18 | 185 nomor KA -> 185 trip
   OK EKONOMI JARAK JAUH               38/4 | 38/4 | 50 nomor KA -> 50 trip
   OK LOKAL EKONOMI                    150/0 | 150/0 | 174 nomor KA -> 174 trip
   OK BANDARA YIA                      26/0 | 26/0 | 26 nomor KA -> 50 trip
   OK BANDARA YIA                      24/0 | 24/0 | 24 nomor KA -> 50 trip
   OK BANDARA SMO                      10/0 | 10/0 | 10 nomor KA -> 10 trip
   OK EKONOMI LOKAL (FEEDER)           66/6 | 66/6 | 72 nomor KA -> 72 trip
   OK COMMUTER LINE DAOP 6 YK          27/7 | 27/7 | 34 nomor KA -> 34 trip
   !! COMMUTER LINE BANDARA SOETTA     70/0 | 64/6 | 140 nomor KA -> 140 trip
   OK COMMUTER LINE DAOP 1 JAK         1055/24 | 1055/24 | 1168 nomor KA -> 1168 trip
  ERRORS: 0
```

Selisih `!!` di atas berasal dari PDF sendiri: judul kelas COMMUTER LINE BANDARA SOETTA menulis REGULER 70 / FAKULTATIF 0, tetapi daftar di bawahnya menandai 6 perjalanan (805F-806F, 807F-808F, 925F-926F, 927F-928F, 933F-934F, 935F-936F) sebagai FAKULTATIF. Total 70 perjalanan cocok; feed mengikuti penanda per baris (fakultatif).

## Baris yang dilewati

KA non-penumpang tidak dimasukkan. Jumlah nomor KA dengan tabel di Lampiran II yang dilewati:

- BARANG HANTARAN PARCEL (BHP): 6
- BARANG PETIKEMAS: 38
- BARANG BBM: 48
- BARANG SEMEN: 24
- BARANG PUPUK: 2
- BARANG TERNAK: 4

KA dinas (perjalanan kosongan rangkaian/lokomotif) hanya tercantum di Buku Penomoran, tanpa tabel waktu di Lampiran II, dan tidak dimasukkan (jumlah perjalanan tertulis, REGULER/FAKULTATIF):
- BARANG DINAS (EJEK): 4/0
- DINAS RANGKAIAN DAOP 1 JAK: 110/10
- DINAS LOKOMOTIF DAOP 1 JAK: 118/20
- DINAS RANGKAIAN DAOP 2 BD: 6/0
- DINAS LOKOMOTIF DAOP 2 BD: 8/0
- DINAS LOKOMOTIF DAOP 3 CN: 6/4
- DINAS RANGKAIAN DAOP 4 SM: 3/2
- DINAS LOKOMOTIF DAOP 4 SM: 26/6
- DINAS RANGKAIAN DAOP 5 PWT: 2/0
- DINAS LOKOMOTIF DAOP 5 PWT: 15/5
- DINAS RANGKAIAN DAOP 6 YK: 15/2
- DINAS LOKOMOTIF DAOP 6 YK: 18/8
- DINAS RANGKAIAN DAOP 7 MN: 2/0
- DINAS RANGKAIAN DAOP 8 SB: 27/5
- DINAS LOKOMOTIF DAOP 8 SB: 110/10

Lampiran II tidak memuat tabel KA Luar Biasa (KLB) atau kosongan selain yang disebut di atas. Baris ambigu/tidak terbaca: tidak ada.

## KA fakultatif (dimasukkan dengan service `*_FAKULTATIF`)

- Purwojaya: 70F, 67F, 72F, 73F, 74F, 71F, 64F, 65F
- borobudur: 75F, 76F, 77F, 78F
- Gajayana Fakultatif: 79F, 80F
- Sancaka: 115F, 116F
- Parahyangan Fakultatif: 141F, 142F
- Cirebon Fakultatif: 143F, 144F
- Sancaka Utara: 215F, 216F, 217F, 218F, 219F, 220F
- Ijen: 222F, 223F, 224F, 221F
- Kaligung: 257F, 258F
- Banyubiru: 259F, 260F, 337F, 338F
- Blora Jaya: 275F, 276F
- Mutiara Timur: 277F, 278F
- Arjuno: 335F, 336F
- Ka Feeder: 611F, 612F, 679F, 680F, 681F, 682F
- Commuter Line Yogyakarta: 710F, 723F, 724F, 731F, 732F, 733F, 734F
- Commuter Line BST: 805F, 806F, 807F, 808F, 925F, 926F, 927F, 928F, 933F, 934F, 935F, 936F
- Commuter Line Bogor: 1021F, 1022F, 1149F, 1150F, 1175F, 1176F, 1207F, 1208F, 1229F, 1230F, 1350F, 1351F, 1407F
- Commuter Line Rangkasbitung: 1606F, 1621F, 1622F, 1625F, 1626F, 1633F, 1634F, 1641F, 1642F, 1657F, 1658F

## Koordinat stasiun

Koordinat hanya diambil dari data yang sudah ada di repo, tidak ada yang dikarang. Urutan prioritas: `supabase/data/gtfs-krl-yogyakarta/stops.txt`, `temp_gtfs/stops.txt` (sebagian besar stop di sini tidak berkoordinat sehingga tidak terpakai), lalu `supabase/data/gtfs-antarkota/candidates/stations_osm_candidates.csv` (cocok kode; bila satu kode punya beberapa baris, dipilih yang namanya cocok). Jika kode tidak ada, dipakai baris OSM yang **namanya** cocok persis dan unik (bukan stasiun kereta cepat).

Sumber per stasiun: stations_osm_candidates.csv: 328, gtfs-krl-yogyakarta/stops.txt: 13, stations_osm_candidates.csv (cocok nama): 14.

Stasiun yang koordinatnya dari kecocokan nama (kode PDF tidak ada di sumber) — mohon dicek:
- BJD (Bojonggede) ← "Bojonggede"
- BOI (Bojongindah) ← "Bojong Indah"
- BPR (Batuceper) ← "Batu Ceper"
- BST (Bandara Soekarno Hatta) ← "Bandara Soekarno-Hatta"
- CLT (Cilebut) ← "Cilebut"
- CTA (Citayam) ← "Citayam"
- DP (Depok) ← "Depok"
- JTK (Jatake) ← "Jatake"
- KDO (Kadipiro) ← "Kadipiro"
- POC (Pondokcina) ← "Pondok Cina"
- PSJ (Pasirjengkol) ← "Pasirjengkol"
- RJ (Rejotangan) ← "Rejotangan"
- THI (Tanah Tinggi) ← "Tanah Tinggi"
- TOJB (Tonjongbaru) ← "Tonjong Baru"

Kode cocok tetapi nama berbeda (dianggap stasiun yang sama; `stop_name` memakai nama dari sumber koordinat):
- SUDB: PDF "Sudirmanbaru" / sumber "BNI City"
- UI: PDF "Univ. Indonesia" / sumber "Universitas Indonesia"
- UP: PDF "Univ. Pancasila" / sumber "Universitas Pancasila"

Stasiun yang di `station_review.json` masih berstatus perlu ditinjau (koordinat tetap dipakai):
- CU Cepu: needs_review — OSM 4 m / Wikidata 147 m from track; sources differ 247 m
- JR Jember: needs_review — OSM 11 m / Wikidata 32 m from track; sources differ 204 m
- PPK Prupuk: needs_review — OSM 4 m / Wikidata 39 m from track; sources differ 273 m
- SBP Sumberpucung: single_source_on_track
- TIS Terisi: single_source_on_track
- WK Walikukun: needs_review — OSM 6 m / Wikidata 58 m from track; sources differ 828 m

Kode ganda di sumber OSM: TGR dipakai "Temuguruh" (baris lain berjarak 730 km diabaikan).

### Stasiun tanpa koordinat

Tidak ada: semua stasiun tempat KA penumpang berhenti mendapat koordinat dari sumber di atas.

## Keterbatasan

- **Halte tanpa waktu (`Berh`/`Sb`)**: 9706 baris stop_times punya `arrival_time`/`departure_time` kosong dan `timepoint=0` (sah menurut spesifikasi GTFS; konsumen boleh menginterpolasi). Terutama KRL Jabodetabek, CL Bandung Raya, CL BST, Pangrango, sebagian CL Dhoho/Penataran/Jenggala. PDF memang tidak mencantumkan waktunya, jadi tidak diisi. **Perhatian:** `admin/lib/gtfs/parser.ts` (parseGtfsTimeOfDay) saat ini menolak waktu kosong, jadi importer perlu disesuaikan (lewati/interpolasi) sebelum feed ini diimpor.
- GAPEKA mencatat semua pemberhentian, termasuk pemberhentian operasional (persilangan/penyusulan, ganti awak). PDF tidak membedakan mana yang melayani naik/turun penumpang, jadi semua halte diberi `pickup_type=0`/`drop_off_type=0`.
- Nama KA mengikuti dokumen (mis. "Anggrek" untuk Argo Bromo Anggrek, "Exspres Rajabasa", "Gajayana Fakultatif"). Nama stasiun mengikuti sumber koordinat.
- Kelas di `route_desc` adalah kelas GAPEKA, bukan kelas kereta/tiket. Satu nama KA bisa punya beberapa kelas (mis. Ambarawa).
- Hanya jadwal dasar GAPEKA; perubahan operasional KAI setelah terbit (KA tambahan, pembatalan, mutasi jadwal) tidak tercakup.
- `route_color` tidak diisi (PDF tidak memuat warna).
