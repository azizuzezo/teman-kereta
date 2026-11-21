# GAPEKA 2026: jadwal baru berlaku 1 Desember 2026

Feed siap-import untuk semua layanan penumpang **non-antarkota** GAPEKA 2026 Jawa, dibangun dari
`supabase/data/gtfs-gapeka-2026-jawa` (KP DJKA 116 Tahun 2026). **Belum ada yang di-import ke database.**

| File | Isi |
|---|---|
| `build_import_feeds.py` | Membangun feed siap-import. Tidak menyentuh database. |
| `import/krl-jabodetabek.zip` | 1.168 perjalanan (termasuk fakultatif), lintas BOGOR, CIKARANG, RANGKAS, TANGERANG, PRIOK |
| `import/krl-yogyakarta.zip` | 34 perjalanan (termasuk fakultatif), lintas YKPL |
| `import/gapeka-kci.zip` | Layanan KCI baru: 14 lintas, 342 perjalanan (12 fakultatif). Lihat bagian di bawah. |
| `import/gapeka-kai.zip` | Layanan lokal KAI: 6 lintas, 104 perjalanan (6 fakultatif). Lihat bagian di bawah. |
| `networks.json` | Pembagian jaringan untuk aplikasi (CONTRACT.md C): 7 jaringan. |
| `station_check.sql` | Cek sebelum import zip `gapeka-*`: stasiun mana yang sudah ada di database dan akan tertimpa. Hanya baca. |
| `cutover.sql` | Pratinjau, pembersihan jadwal lama mulai 1 Des, dan cek pasca-import. Dijalankan manual. |

## Kenapa jadwal baru otomatis mulai 1 Desember

Importer membuat perjalanan per tanggal hanya untuk hari yang tercakup `calendar.txt`
(`ServiceCalendar.runsOn` memeriksa `start_date`/`end_date`), **asalkan** skrip dijalankan dengan
`--respect-calendar` (lihat langkah 5) atau lewat importer admin web. Kalender feed ini mulai `20261201`, jadi
meskipun di-import beberapa hari sebelumnya, perjalanan GAPEKA 2026 baru ada mulai 1 Desember.
Jadwal sampai 30 November tidak berubah.

## Apa yang disesuaikan dari feed GAPEKA mentah

1. **Dua zip lama untuk jaringan yang sudah ada** (KRL Jabodetabek, KRL Yogyakarta, operator "KAI Commuter"),
   isinya tidak berubah. Layanan non-antarkota lain ada di `gapeka-kci.zip` dan `gapeka-kai.zip` (bagian
   "Layanan non-antarkota lain" di bawah). KA antarkota tidak ikut.
2. **Data stasiun dan lintas tidak tertimpa.** Importer menimpa nama, fasilitas (`stop_desc`), warna, dan nama
   lintas dari isi feed. Baris stasiun dan lintas diambil dari feed yang membangun data sekarang
   (`temp_gtfs`, `gtfs-krl-yogyakarta`). Koordinat kosong berarti importer mempertahankan koordinat di database.
   Hanya stasiun baru di GAPEKA 2026 yang diambil dari feed GAPEKA: **JIS** (Jakarta International Stadium)
   dan **JTK** (Jatake).
3. **Kode lintas dipetakan** ke kode yang sudah ada, supaya tidak muncul lintas duplikat
   (`RANGKASBITUNG`/`TANJUNG_PRIOK` diubah importer menjadi `RANGKAS`/`PRIOK` lewat `ROUTE_ID_REMAP`).
4. **Jam kosong diisi.** PDF tidak mencetak jam di banyak stasiun tempat kereta berhenti (Berh/Sb):
   9.384 baris KRL Jabodetabek. Jam diisi di antara dua jam GAPEKA yang tercetak, memakai proporsi waktu tempuh
   dari jadwal lama (6.655 baris) atau jarak garis lurus kalau tidak ada data lama (2.729 baris), dibulatkan
   ke menit dan ditandai `timepoint=0` (perkiraan). Jam yang tercetak di GAPEKA tidak diubah.
   Uji leave-one-out terhadap jadwal lama: median selisih 1 menit, 90% ≤ 3 menit, 99% ≤ 7 menit.
5. **Fakultatif ikut** (24 perjalanan Jabodetabek, 7 Yogyakarta), dengan `service_id` `GJ26_FAKULTATIF` supaya aplikasi bisa menandainya. Untuk mengecualikan: `--exclude-fakultatif`.

## Layanan non-antarkota lain (`gapeka-kci.zip`, `gapeka-kai.zip`)

Satu zip per operator. `routes.agency_id` tetap ada (`KCI` / `KAI`) supaya importer bisa memetakan lintas ke
operator dengan `--operator-map KAI=<uuid>,KCI=<uuid>`. Kode lintas baru tanpa prefiks `GJ26_`, tidak bentrok dengan
kode lama (BOGOR, CIKARANG, RANGKAS, TANGERANG, PRIOK, NAMBO, YKPL) atau alias aplikasi (RANGKASBITUNG,
TANJUNG_PRIOK, BEKASI, SERPONG). Aturannya: nama KA tanpa spasi; lintas bandara dan Bandung Raya memakai bentuk
pendek (BST, YIA, SMO, BDR seperti di CONTRACT.md). `route_color` kosong (PDF tidak memuat warna, tidak dikarang).
`route_desc` menyimpan kelas GAPEKA.

Kolom: perjalanan (fakultatif) / baris stop_times / jam tercetak / jam diisi (`timepoint=0`) / stasiun.

| Zip | Lintas | `route_long_name` | Perj. (fak.) | Baris | Tercetak | Diisi | Stasiun |
|---|---|---|---:|---:|---:|---:|---:|
| kci | BST | Commuter Line Bandara Soetta | 140 (12) | 502 | 432 | 70 | 8 |
| kci | YIA | Commuter Line Bandara YIA | 50 | 124 | 124 | 0 | 3 |
| kci | PRAMEKS | Commuter Line Prameks | 10 | 54 | 54 | 0 | 7 |
| kci | BDR | Commuter Line Bandung Raya | 38 | 499 | 351 | 148 | 22 |
| kci | GARUT | Commuter Line Garut | 6 | 147 | 117 | 30 | 30 |
| kci | WALAHAR | Commuter Line Walahar | 10 | 100 | 100 | 0 | 10 |
| kci | JATILUHUR | Commuter Line Jatiluhur | 4 | 29 | 29 | 0 | 8 |
| kci | MERAK | Commuter Line Merak | 14 | 154 | 154 | 0 | 11 |
| kci | DHOHO | Commuter Line Dhoho | 13 | 267 | 243 | 24 | 46 |
| kci | PENATARAN | Commuter Line Penataran | 13 | 271 | 247 | 24 | 49 |
| kci | JENGGALA | Commuter Line Jenggala | 23 | 161 | 153 | 8 | 22 |
| kci | SUPAS | Commuter Line Supas | 8 | 78 | 78 | 0 | 12 |
| kci | ARJONEGORO | Commuter Line Arjonegoro | 9 | 77 | 77 | 0 | 18 |
| kci | BLORASURA | Commuter Line Blorasura | 4 | 56 | 56 | 0 | 14 |
| **kci** | **14 lintas** | | **342 (12)** | **2.519** | **2.215** | **304** | **134** |
| kai | SMO | KA Bandara Adi Soemarmo | 10 | 107 | 107 | 0 | 13 |
| kai | FEEDER | KA Feeder Padalarang - Bandung | 72 (6) | 216 | 216 | 0 | 3 |
| kai | BATARAKRESNA | KA Batara Kresna | 8 | 40 | 40 | 0 | 5 |
| kai | KEDUNGSEPUR | KA Kedung Sepur | 4 | 52 | 52 | 0 | 13 |
| kai | PANDANWANGI | KA Pandanwangi | 4 | 44 | 44 | 0 | 11 |
| kai | SILIWANGI | KA Siliwangi | 6 | 54 | 54 | 0 | 9 |
| **kai** | **6 lintas** | | **104 (6)** | **513** | **513** | **0** | **54** |

- **Jam kosong** (304 baris, semuanya di zip KCI) diisi dengan cara yang sama seperti KRL Jabodetabek. Tidak ada
  jadwal lama dengan urutan stasiun yang sama untuk celah-celah ini, jadi **semua 304 diisi berdasarkan jarak garis
  lurus** (0 dari profil jadwal lama), dibulatkan ke menit, `timepoint=0`. Belum ada uji akurasi untuk lintas ini
  (tidak ada data pembanding). Jam tercetak tidak diubah; dicek: tidak ada jam kosong, jam tidak pernah mundur.
- **Stasiun.** Kode yang ada di `temp_gtfs` atau `gtfs-krl-yogyakarta` memakai baris dari sana (fasilitas dan nama
  tetap; koordinat kosong = koordinat database dipertahankan): KCI 10 (BOO, BPR, CKR, DPB, DU, MRI, RK, RW, SUDB
  dari `temp_gtfs`; YK dari `gtfs-krl-yogyakarta`), KAI 4 (PL, PWS, SK, SLO dari `gtfs-krl-yogyakarta`). Kode lain
  memakai nama dan koordinat feed GAPEKA (koordinat dari sumber repo, lihat README feed GAPEKA): 124 di zip KCI, 50
  di zip KAI, **171 kode unik** (BD, CMI, PDL ada di keduanya).
- **Fakultatif ikut** (BST 12, FEEDER 6) dengan `service_id` `GJ26_FAKULTATIF`; `--exclude-fakultatif` berlaku juga di sini.

### Risiko: stasiun yang mungkin menimpa data database

Importer meng-upsert stasiun berdasarkan kode. Untuk 171 kode di bawah, kalau kode itu **sudah ada** di database
(misalnya ditambah lewat admin), nama dan koordinatnya diganti dengan nilai feed GAPEKA, fasilitas menjadi `{}`, dan
`wheelchair_accessible` menjadi `null`. Isi database tidak bisa dicek dari sini. **Sebelum import, jalankan
`station_check.sql`** (hanya baca): hasil kosong berarti tidak ada baris yang tertimpa; kalau ada baris, putuskan
dulu per stasiun (hapus kode itu dari zip atau terima nilai feed).

¹ koordinat dari kecocokan nama (kode PDF tidak ada di sumber), ² berstatus perlu ditinjau di `station_review.json`.

AGO Argopuro, ATA Alastua, BBG Brumbung, BBT Babat, BD Bandung, BG Bangil, BH Boharan, BJ Bojonegoro, BL Blitar,
BMG Blimbing, BNW Benowo, BST¹ Bandara Soekarno-Hatta, BWI Banyuwangi Kota, BWO Bowerno, BYM Bayeman, CA Ciganea,
CB Cibatu, CBB Cibeber, CBR Cibungur, CCL Cicalengka, CD Cikadongdong, CIR Ciroyom, CJ Cianjur, CKL Cikeusal,
CKP Cikampek, CLE Cilame, CLG Cilegon, CMD Cimindi, CME Cerme, CMI Cimahi, CMK Cimekar, CPT Cipatat, CPY Cipeuyeum,
CRB Caruban, CRG Cireungas, CRJ Ciranjang, CRM Curahmalang, CT Catang, CTH Cikudapateuh, CU² Cepu, DD Duduk,
DWN Dawuan, GDB Gedebage, GDG Gedangan, GDS Gandasoli, GK Gadobangkong, GLM Glenmore, GRM Garum, GRT Garut,
GUB Gubug, HRP Haurpugur, IDO Indro, JBU Jambu Baru, JG Jombang, JN Jenar, JR² Jember, JRK Jerakah,
KAC Kiaracondong, KBD Kalibodri, KBR Kalibaru, KD Kediri, KDA Kandangan, KDB Kedungbanteng, KDH Kedunggedeh,
KDN Kedinding, KDO¹ Kadipiro, KEN Krenceng, KG Kedunggalar, KGT Karangjati, KLI Klari, KLN Kaliwungu, KLT Kalisat,
KM Kebumen, KOS Kosambi, KPN Kepanjen, KPS Kapas, KRA Karangantu, KRAI Karangsari, KRN Krian, KRS Kras,
KSB Kesamben, KSL Kalisetail, KTA Kutoarjo, KTG Ketapang, KTS Kertosono, KW Karawang, KWN Kutowinangun, LL Leles,
LMB Lemahabang, LMG Lamongan, LO Leuwigoong, LP Lampegan, LW Lawang, MAG Magetan, MER Merak, MGN Minggiran,
MKG Mangkang, ML Malang, MLK Malang Kotalama, MN Madiun, MR Mojokerto, MSI Maswati, NB Ngebruk, NBO Ngrombo,
NDL Ngadiluwih, NG Nagreg, NGW Ngawi, NJG Ngujang, NT Ngunut, PB Probolinggo, PC Pucuk, PDL Padalarang, PGJ Pogajih,
PLD Plered, PNT Pasarnguter, PPR Papar, PR Porong, PS Pasuruan, PSI Pakisaji, PSJ¹ Pasirjengkol, PTR Peterongan,
PWA Purwoasri, PWK Purwakarta, RCK Rancaekek, RGP Rogojampi, RH Rendeh, RJ¹ Rejotangan, SB Surabaya Kota,
SBI Surabaya Pasarturi, SBL Sumbergempol, SBO Sumobito, SBP² Sumberpucung, SDA Sidoarjo, SDI Sedadi, SG Serang,
SGS Singosari, SGU Surabaya Gubeng, SI Sukabumi, SKH Sukoharjo, SKT Sasaksaat, SMB Sembung, SMC Semarang Poncol,
SMO Adi Soemarmo, SMT Semarang Tawang, SPJ Sepanjang, SR Sragen, SRJ Sumberrejo, SS Susuhan, STA Solo Kota,
SUT Sukatani, SWD Sumberwadung, TA Tulungagung, TAL Talun, TES Tandes, TGA Tanggulangin, TGR Temuguruh,
TLN Tulangan, TOJB¹ Tonjong Baru, TRK Tarik, WG Wlingi, WJ Wojo, WK² Walikukun, WLR Weleri, WLT Walantaka,
WN Wonokerto, WNG Wonogiri, WNR Wanaraja, WO Wonokromo, WR Waru, WT Wates, YIA Yogyakarta International Airport

## Jaringan (`networks.json`)

Aplikasi memblokir perjalanan antar-jaringan, jadi satu jaringan = stasiun yang bisa dicapai satu sama lain dengan
kereta di aplikasi ini, termasuk transit. Dikelompokkan per wilayah, lalu dicek di skrip: setiap lintas masuk tepat
satu jaringan, dan lintas dalam satu jaringan tersambung lewat stasiun bersama (kalau tidak, build berhenti).
Stasiun = jumlah kode stasiun yang disinggahi lintas di jaringan itu.

| `id` | Label | Lintas | Stasiun |
|---|---|---|---:|
| `jabodetabek` | Jabodetabek | BOGOR, CIKARANG, RANGKAS, TANGERANG, PRIOK, NAMBO, BST, MERAK, WALAHAR, JATILUHUR | 104 |
| `jogja` | Yogyakarta | YKPL, YIA, PRAMEKS, SMO, BATARAKRESNA | 34 |
| `bandung` | Bandung Raya | BDR, GARUT, FEEDER | 30 |
| `jatim` | Jawa Timur | DHOHO, PENATARAN, JENGGALA, SUPAS, ARJONEGORO, BLORASURA | 68 |
| `semarang` | Semarang | KEDUNGSEPUR | 13 |
| `sukabumi` | Sukabumi-Cianjur | SILIWANGI | 9 |
| `banyuwangi` | Jember-Banyuwangi | PANDANWANGI | 11 |

Alasan penyesuaian dari usulan awal:

- **MERAK, WALAHAR, JATILUHUR masuk Jabodetabek.** Merak bertemu Commuter Line Rangkasbitung di RK; Walahar dan
  Jatiluhur bertemu Commuter Line Cikarang di CKR. Kalau dipisah, RK dan CKR (stasiun KRL besar) jadi stasiun
  lintas-jaringan.
- **Satu-satunya stasiun lintas-jaringan: PWK (Purwakarta)**, disinggahi WALAHAR (jabodetabek) dan BDR + GARUT
  (bandung). Lewat PWK, Jabodetabek dan Bandung sebenarnya tersambung (CKR - Walahar - PWK - Bandung Raya/Garut),
  tetapi hanya oleh 1 perjalanan BDR (CCL ke PWK) dan 3 perjalanan GARUT (PWK - GRT); menggabungkan keduanya jadi satu
  jaringan tidak sepadan. Aplikasi perlu memutuskan PWK masuk jaringan mana (petanya per stasiun).
- **jogja** mencakup Solo dan sekitarnya: PRAMEKS dan YIA bertemu YKPL di YK, BATARAKRESNA di PWS, SMO di SLO/SK/PL.
  SMO juga sampai MN (Madiun) dan CRB (Caruban), yang tidak disinggahi lintas jatim mana pun.
- **jatim**: keenam lintas saling bertemu (SB, SGU, WO, SDA, dll.). BLORASURA sampai CU (Cepu, Jawa Tengah).
- **semarang, sukabumi, banyuwangi** masing-masing satu lintas yang tidak berbagi stasiun dengan lintas lain:
  KEDUNGSEPUR (Weleri - Ngrombo), SILIWANGI (Sukabumi - Cipatat, tidak sampai PDL), PANDANWANGI (Jember - Ketapang).
  Kalau digabung ke jaringan wilayahnya, aplikasi akan menawarkan tujuan yang tidak bisa dicapai.
- **NAMBO** dicantumkan karena aplikasi mengenal kode itu; tidak ada feed di sini yang menghasilkan lintas NAMBO
  (perjalanan Nambo ada di lintas BOGOR).

## Skema saklar: semua disiapkan dulu, 1 Desember cukup satu tombol

Perjalanan GAPEKA disimpan di **set jadwal** tersendiri (`gapeka2026`) yang tidak terlihat pengguna. Satu tombol di
admin web (halaman **Jadwal**) menentukan set mana yang dilihat aplikasi; tanpa build ulang, tanpa SQL manual, tanpa
menghapus jadwal lama. Tombol yang sama mengembalikan ke jadwal lama kapan saja.

Cara kerjanya (migrasi `20261122090000_schedule_switch.sql`): `trips.schedule_set` menandai set tiap perjalanan
(bawaan `lama`, jadi seluruh data sekarang tetap berlaku). `schedule_control` menyimpan set aktif dan satu pergantian
terjadwal. Tiga RPC jadwal, estimasi posisi kereta, dan rentang jadwal (`get_schedule_window`) hanya membaca set yang
aktif. Pergantian terjadwal berlaku tepat waktunya dengan jam server, tanpa cron.

### Persiapan (boleh kapan saja, tidak terlihat pengguna)

1. **Rilis aplikasi 1.5.0 dan tunggu pengguna memperbaruinya.** Aplikasi lama menganggap semua lintas selain YKPL
   sebagai Jabodetabek, jadi jangan import zip `gapeka-kci`/`gapeka-kai` (lini baru) sebelum itu.
2. **Terapkan migrasi berurutan:** `20261118090000_gapeka_estimated_times.sql`, lalu `20261122090000_schedule_switch.sql`.
   Perilaku aplikasi tidak berubah (set `lama` aktif). Deploy admin web setelahnya.
3. **Import SEKALI dengan set `gapeka2026`**, jendela 7 hari yang mulai tepat di hari berlaku (1-7 Desember). Id operator
   ambil dari blok 3 `cutover.sql`. **Tidak perlu import ulang** setelah itu: lihat "Kenapa cukup sekali" di bawah.
   ```bash
   cd admin
   node node_modules/tsx/dist/cli.mjs scripts/import-real-gtfs.mts ../supabase/data/gapeka-2026/import/krl-jabodetabek.zip <operator-id> 7 --respect-calendar --schedule-set gapeka2026 --start-date 2026-12-01
   node node_modules/tsx/dist/cli.mjs scripts/import-real-gtfs.mts ../supabase/data/gapeka-2026/import/krl-yogyakarta.zip <operator-id> 7 --respect-calendar --schedule-set gapeka2026 --start-date 2026-12-01
   ```
   Lalu layanan non-antarkota lain (jalankan `station_check.sql` dulu, selesaikan setiap baris yang muncul):
   ```bash
   node node_modules/tsx/dist/cli.mjs scripts/import-real-gtfs.mts ../supabase/data/gapeka-2026/import/gapeka-kci.zip 7 --operator-map KAI=<uuid-kai>,KCI=<uuid-kci> --respect-calendar --schedule-set gapeka2026 --start-date 2026-12-01
   node node_modules/tsx/dist/cli.mjs scripts/import-real-gtfs.mts ../supabase/data/gapeka-2026/import/gapeka-kai.zip 7 --operator-map KAI=<uuid-kai>,KCI=<uuid-kci> --respect-calendar --schedule-set gapeka2026 --start-date 2026-12-01
   ```
   Skrip menolak feed yang berlaku di masa depan bila `--schedule-set` tidak diberikan, dan menolak set selain `lama`
   bila migrasi saklar belum ada.
4. **Periksa di halaman Jadwal:** set `gapeka2026` harus menampilkan jumlah perjalanan dan rentang tanggal
   (2026-12-01 s/d 2026-12-07) yang masuk akal; set `lama` tetap yang aktif.

### Kenapa cukup sekali (tanpa import ulang tiap hari)

Tabel `trips` menyimpan perjalanan per tanggal, tetapi aplikasi tidak butuh tanggal hari ini ada di sana. Saat RPC tidak
punya baris untuk hari ini, aplikasi mengambil jadwal pada hari-minggu yang sama di dalam jendela set aktif (kelipatan 7
hari) dan memajukannya ke hari ini. Jadwal lama berjalan begitu sejak Agustus: hanya 7-13 Agustus yang ada di database,
dan jadwal hari ini tetap tampil. GAPEKA 2026 tidak punya pola hari (semua harian), jadi satu pekan sudah mewakili seluruh
masa berlakunya. Syaratnya jendela minimal 7 hari; 7 hari juga paling hemat ruang database (kira-kira separuh dari 14 hari).

Keterbatasan yang sudah ada sejak jadwal lama: fitur yang butuh tanggal sungguhan, yaitu estimasi posisi kereta dari jadwal
(`refresh_estimated_vehicle_positions`), hanya bekerja untuk tanggal yang ada di jendela. Posisi dari penumpang tidak terpengaruh.

### Pergantian

5. Di halaman **Jadwal**, pada set `gapeka2026` tekan **Jadwalkan 1 Desember 00:00 WIB**. Jadwal berganti sendiri tepat
   tengah malam. (Atau **Aktifkan sekarang** untuk berganti seketika.)
6. **Kalau ada masalah:** tekan **Aktifkan sekarang** pada set `lama`. Seketika, tanpa kehilangan data.
7. Aplikasi menyimpan rentang jadwal sampai 1 jam, jadi sebagian pengguna baru melihat pergantian dalam waktu itu.

Catatan: stasiun dan lini bersifat global, bukan per set. Lini baru (Bandara, Bandung Raya, dst.) dan perubahan data
stasiun ikut terlihat sejak diimpor; yang tersembunyi sampai pergantian adalah keberangkatan dan hasil pencarian rute.

## Setelah cutover

- **Tidak ada import ulang rutin.** GAPEKA berlaku sampai diganti GAPEKA berikutnya; import berikutnya hanya saat ada GAPEKA baru
  (set baru, mis. `gapeka2027`, lalu tombol yang sama).
- **Jangan import ulang feed lama** dengan jendela yang melewati 30 November, dan jangan menghapus set `lama` sampai
  GAPEKA 2026 terbukti stabil (itu jalan mundur lewat tombol).
- Importer menyimpan `timepoint=0` sebagai `stop_times.is_estimated = true` (migrasi 20261118090000). Aplikasi
  menampilkannya sebagai jam perkiraan mulai versi yang membaca kolom ini (rilis 1.4.0, sedang dikerjakan).
- **Antarkota tidak tercakup di sini.** Data antarkota dibundel di aplikasi (`assets/intercity/intercity_v1.json`)
  sebagai katalog rute dengan perkiraan waktu tempuh, bukan jadwal. Memakai jam GAPEKA di sana butuh rilis aplikasi.
  Yang tidak ikut dari feed Jawa: 87 rute, 319 perjalanan (42 fakultatif) berkelas ARGO, EKSEKUTIF, EKSEKUTIF CAMPURAN atau EKONOMI
  JARAK JAUH (daftar lengkap dicetak `build_import_feeds.py`). Feed Sumbagsel (`gtfs-gapeka-2026-sumbagsel`) hanya
  berisi 4 rute, 10 perjalanan berkelas EKONOMI / EKSEKUTIF BISNIS (Bukit Serelo, Exspres Rajabasa, Kuala Stabas,
  Sindang Marga), tanpa kelas lokal atau commuter, jadi juga tidak ikut di sini.
