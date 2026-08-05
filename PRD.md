# MASTER PROMPT — PRD DAN PENGEMBANGAN APLIKASI TK

Bertindaklah sebagai gabungan dari:

* Senior Product Manager.
* Senior Flutter Developer.
* Android Native Developer.
* UI/UX Designer.
* Backend Engineer.
* Transit Data Engineer.
* GIS dan Navigation Engineer.
* Software Architect.
* Quality Assurance Engineer.
* Mobile Security Engineer.

Buat aplikasi Android berbasis Flutter bernama:

# TK — Teman Kereta

Tagline:

**Teman Perjalanan KRL Setiap Hari**

TK adalah aplikasi pendamping perjalanan khusus pengguna Commuter Line/KRL yang membantu pengguna merencanakan perjalanan, melihat jadwal terbaru, mengetahui posisi kereta, mendeteksi perjalanan secara otomatis, menerima panduan selama berada di kereta, mendapatkan notifikasi sebelum stasiun tujuan, menemukan tempat menarik di sekitar stasiun, serta melanjutkan perjalanan dengan moda transportasi lainnya.

Aplikasi harus gratis digunakan oleh pengguna, tanpa iklan mengganggu, tanpa paket premium, dan tanpa fitur penting yang dikunci.

Gunakan pendekatan **free-first architecture**. Semua layanan utama harus menggunakan teknologi open-source atau free tier selama memungkinkan. Namun, jangan menggunakan API ilegal, scraping endpoint privat, data palsu, atau data yang melanggar ketentuan penyedia.

---

# 1. TUJUAN PRODUK

Tujuan utama TK adalah membuat perjalanan menggunakan KRL menjadi:

* Lebih mudah direncanakan.
* Lebih aman.
* Lebih informatif.
* Tidak membuat pengguna takut kelewatan stasiun.
* Lebih mudah berpindah moda transportasi.
* Lebih mudah menemukan lokasi penting di sekitar stasiun.
* Tetap berguna walaupun aplikasi tidak sedang dibuka.
* Ramah bagi pengguna baru, pengguna rutin, anak-anak, lansia, dan penyandang disabilitas.

TK tidak hanya menjadi aplikasi jadwal kereta, tetapi menjadi pendamping perjalanan dari lokasi awal sampai pengguna tiba di tujuan akhir.

---

# 2. TARGET PENGGUNA

## 2.1 Pengguna Harian

Pengguna yang setiap hari menggunakan rute yang sama untuk bekerja, kuliah, atau sekolah.

Kebutuhan:

* Melihat jadwal kereta berikutnya.
* Mendapat notifikasi keterlambatan.
* Menyimpan rute favorit.
* Melihat estimasi waktu perjalanan.
* Memasang widget jadwal di layar utama.

## 2.2 Pengguna Baru

Pengguna yang belum memahami jalur KRL, transit, peron, atau stasiun tujuan.

Kebutuhan:

* Panduan langkah demi langkah.
* Informasi tempat transit.
* Informasi jumlah stasiun.
* Peringatan sebelum turun.
* Penjelasan jalur menggunakan bahasa sederhana.

## 2.3 Wisatawan

Pengguna yang ingin mengunjungi destinasi wisata atau tempat populer menggunakan KRL.

Kebutuhan:

* Rekomendasi destinasi dekat stasiun.
* Informasi jarak berjalan kaki.
* Integrasi transportasi lanjutan.
* Estimasi waktu dan biaya perjalanan.

## 2.4 Pengguna Berkebutuhan Khusus

Kebutuhan:

* Ukuran teks yang dapat diperbesar.
* Dukungan screen reader.
* Kontras warna yang baik.
* Getaran dan suara sebagai pengingat.
* Informasi fasilitas stasiun.
* Informasi lift, eskalator, toilet, dan akses kursi roda apabila datanya tersedia.

---

# 3. BATASAN DAN PRINSIP PRODUK

Aplikasi harus mengikuti prinsip berikut:

1. Tidak boleh menampilkan posisi kereta sebagai real-time jika sumbernya hanya estimasi.
2. Posisi kereta harus memiliki label sumber:

   * Real-time.
   * Terakhir diperbarui.
   * Estimasi berdasarkan jadwal.
   * Data tidak tersedia.
3. Jangan mengambil data dari endpoint internal aplikasi lain tanpa izin.
4. Gunakan API resmi, data terbuka, GTFS Schedule, GTFS-Realtime, atau sumber data berizin.
5. Jadwal tidak boleh di-hardcode di dalam aplikasi.
6. Semua fitur tetap memiliki kondisi kosong, loading, error, offline, dan retry.
7. Aplikasi tidak boleh terus mengambil GPS dengan interval tinggi ketika pengguna tidak sedang melakukan perjalanan.
8. Lokasi pengguna harus diproses di perangkat sebanyak mungkin.
9. Jangan menjual atau membagikan data lokasi pengguna.
10. Semua izin harus dijelaskan sebelum dialog izin Android ditampilkan.
11. Pengguna harus dapat menggunakan fitur jadwal dasar tanpa membuat akun.
12. Tidak boleh ada tombol pajangan yang tidak berfungsi.
13. Jangan membuat data dummy terlihat seperti data operasional asli.
14. Mode demo harus diberi label “Data Demo”.
15. Aplikasi harus tetap ringan untuk ponsel Android kelas menengah dan bawah.

---

# 4. CAKUPAN TRANSPORTASI

Prioritas utama adalah:

* Commuter Line Jabodetabek.
* Commuter Line wilayah lain jika data tersedia.
* Kereta Bandara.
* MRT Jakarta.
* LRT Jakarta.
* LRT Jabodebek.
* TransJakarta.
* Mikrotrans.
* Bus kota.
* Angkot.
* Transportasi online melalui deep link.
* Berjalan kaki.
* Sepeda.

Arsitektur data tidak boleh dibuat khusus untuk satu operator saja. Gunakan sistem provider dan adapter agar operator baru dapat ditambahkan tanpa mengubah keseluruhan aplikasi.

---

# 5. FITUR UTAMA

## 5.1 Onboarding

Buat onboarding maksimal empat halaman.

### Halaman 1 — Selamat Datang

Tampilkan:

* Logo TK.
* Nama Teman Kereta.
* Ilustrasi KRL modern.
* Penjelasan singkat manfaat aplikasi.
* Tombol “Mulai”.

### Halaman 2 — Lokasi

Jelaskan bahwa lokasi digunakan untuk:

* Menemukan stasiun terdekat.
* Mendeteksi perjalanan aktif.
* Memberikan peringatan sebelum stasiun tujuan.
* Menampilkan petunjuk perjalanan.

Sediakan:

* Aktifkan lokasi saat aplikasi digunakan.
* Aktifkan lokasi selama perjalanan.
* Lewati untuk sekarang.

Jangan langsung meminta akses lokasi sepanjang waktu. Minta izin bertahap sesuai kebutuhan.

### Halaman 3 — Notifikasi

Jelaskan jenis notifikasi:

* Jadwal keberangkatan.
* Kereta mendekati stasiun.
* Peringatan transit.
* Peringatan dua atau tiga stasiun sebelum tujuan.
* Gangguan perjalanan.
* Perubahan jadwal.
* Kereta terakhir.

### Halaman 4 — Rute Harian

Pengguna dapat memilih:

* Stasiun rumah.
* Stasiun kantor atau kampus.
* Waktu berangkat.
* Waktu pulang.
* Hari aktif.

Semua bagian dapat dilewati.

---

# 6. HALAMAN BERANDA

Beranda harus memberikan informasi terpenting tanpa membuat pengguna banyak menekan tombol.

## Komponen Beranda

### Header

Tampilkan:

* Sapaan berdasarkan waktu.
* Nama pengguna jika tersedia.
* Status koneksi data.
* Foto profil atau avatar.
* Tombol notifikasi.

### Stasiun Terdekat

Tampilkan:

* Nama stasiun.
* Jarak dari pengguna.
* Estimasi waktu berjalan kaki.
* Status operasional.
* Tombol “Lihat Kereta”.
* Tombol “Arah ke Stasiun”.

### Perjalanan Cepat

Form sederhana:

* Dari.
* Ke.
* Waktu berangkat sekarang atau pilih waktu.
* Tombol “Cari Perjalanan”.
* Tombol tukar stasiun.

### Kereta Berikutnya

Tampilkan tiga sampai lima keberangkatan terdekat:

* Waktu keberangkatan.
* Tujuan akhir kereta.
* Nomor perjalanan jika tersedia.
* Peron jika tersedia.
* Status tepat waktu atau terlambat.
* Estimasi tiba.
* Tingkat kepadatan jika tersedia.
* Sumber dan waktu pembaruan data.

### Rute Favorit

Contoh:

* Rumah → Kantor.
* Rumah → Kampus.
* Bogor → Manggarai.
* Bekasi → Sudirman.

### Status Layanan

Tampilkan kartu status setiap jalur:

* Normal.
* Ada keterlambatan.
* Perjalanan terbatas.
* Gangguan.
* Informasi belum tersedia.

Gunakan warna dan ikon, jangan hanya mengandalkan warna.

### Perjalanan Aktif

Apabila perjalanan sedang berjalan, tampilkan kartu besar:

* Kereta atau rute yang sedang digunakan.
* Stasiun sebelumnya.
* Stasiun berikutnya.
* Tujuan akhir pengguna.
* Jumlah stasiun tersisa.
* Estimasi tiba.
* Tombol buka navigasi perjalanan.

---

# 7. PENCARIAN JADWAL KRL

Pengguna dapat mencari jadwal berdasarkan:

* Stasiun keberangkatan.
* Stasiun tujuan.
* Tanggal.
* Waktu keberangkatan.
* Waktu tiba yang diinginkan.
* Kereta langsung.
* Perjalanan dengan transit.
* Jumlah transit maksimal.
* Moda transportasi.
* Preferensi berjalan kaki.

## Hasil Pencarian

Setiap hasil harus menampilkan:

* Waktu berangkat.
* Waktu tiba.
* Durasi perjalanan.
* Jumlah stasiun.
* Jumlah transit.
* Stasiun transit.
* Waktu tunggu transit.
* Nama atau warna jalur.
* Estimasi tarif.
* Status layanan.
* Tingkat kepadatan jika tersedia.
* Jarak berjalan kaki.
* Waktu pembaruan data.

Sediakan pilihan pengurutan:

* Paling cepat.
* Transit paling sedikit.
* Jalan kaki paling sedikit.
* Berangkat paling dekat.
* Biaya paling hemat.

## Detail Perjalanan

Tampilkan perjalanan sebagai timeline:

1. Berjalan menuju stasiun awal.
2. Masuk ke stasiun.
3. Naik kereta dengan tujuan tertentu.
4. Melewati daftar stasiun.
5. Turun atau transit.
6. Berpindah peron jika datanya tersedia.
7. Naik kereta berikutnya.
8. Turun di stasiun tujuan.
9. Melanjutkan perjalanan dengan berjalan kaki atau moda lain.

---

# 8. POSISI KERETA REAL-TIME

Buat halaman peta yang menampilkan:

* Jalur rel.
* Semua stasiun.
* Kereta yang sedang berjalan.
* Arah perjalanan kereta.
* Stasiun berikutnya.
* Status keterlambatan.
* Waktu pembaruan terakhir.
* Posisi pengguna.
* Rute aktif pengguna.

## Tingkat Keakuratan Data

Gunakan empat tingkat status:

### Real-time

Data berasal dari feed kendaraan resmi dan masih berada di bawah batas waktu kesegaran.

### Hampir Real-time

Data sedikit terlambat tetapi masih relevan.

### Estimasi

Posisi dihitung menggunakan jadwal, stasiun terakhir, dan estimasi waktu perjalanan.

### Tidak Tersedia

Jangan tampilkan posisi yang dibuat-buat.

## Tampilan Kereta

Ketika ikon kereta dipilih, tampilkan bottom sheet:

* Tujuan akhir.
* Jalur.
* Nomor perjalanan.
* Stasiun sebelumnya.
* Stasiun berikutnya.
* Estimasi tiba.
* Keterlambatan.
* Daftar pemberhentian.
* Tingkat kepadatan jika tersedia.
* Tombol “Ikuti Kereta”.
* Tombol “Gunakan Perjalanan Ini”.

---

# 9. DETEKSI OTOMATIS KETIKA PENGGUNA NAIK KRL

Fitur ini merupakan fitur unggulan TK.

Aplikasi harus mampu memperkirakan apakah pengguna sudah berada di dalam KRL tanpa menyatakan hasil yang belum pasti sebagai fakta.

## Sinyal yang Digunakan

Gabungkan beberapa sinyal:

* Pengguna memasuki geofence stasiun.
* Pengguna meninggalkan geofence stasiun.
* Aktivitas berubah menjadi berada di kendaraan.
* Kecepatan bergerak sesuai pola perjalanan kereta.
* Posisi berada dekat koridor rel.
* Arah pergerakan sesuai jalur kereta.
* Urutan stasiun yang dilewati.
* Jadwal keberangkatan di stasiun tersebut.
* Perjalanan yang sebelumnya dipilih pengguna.
* Feed posisi kereta yang tersedia.
* Jeda atau berhenti di posisi stasiun.

## Confidence Score

Buat nilai keyakinan antara 0 sampai 100.

Contoh:

* Di bawah 50: jangan tampilkan konfirmasi.
* 50–79: tampilkan pertanyaan ringan.
* 80 ke atas: tampilkan dugaan perjalanan dengan pilihan konfirmasi.

Contoh notifikasi:

> Sepertinya kamu sedang berada di Commuter Line menuju Jakarta Kota. Mulai panduan perjalanan?

Pilihan:

* Ya, mulai.
* Pilih kereta lain.
* Bukan.
* Jangan tanya lagi hari ini.

Jangan memulai pelacakan intensif tanpa persetujuan pengguna.

## Pencocokan Kereta

Setelah pengguna mengonfirmasi, cocokkan pengguna dengan kandidat kereta berdasarkan:

* Stasiun keberangkatan.
* Waktu keberangkatan.
* Jalur.
* Arah perjalanan.
* Urutan stasiun.
* Posisi feed kendaraan.
* Selisih waktu.
* Kecepatan dan arah perangkat.

Apabila terdapat lebih dari satu kandidat, pengguna diminta memilih.

---

# 10. MODE PERJALANAN AKTIF

Saat perjalanan dimulai, tampilkan halaman navigasi perjalanan penuh.

## Informasi Utama

* Nama jalur.
* Tujuan kereta.
* Stasiun sekarang.
* Stasiun berikutnya.
* Tujuan pengguna.
* Jumlah stasiun tersisa.
* Estimasi waktu tiba.
* Waktu keterlambatan.
* Progress bar perjalanan.
* Status GPS.
* Status data real-time atau estimasi.

## Timeline Stasiun

Tampilkan:

* Stasiun yang telah dilewati.
* Stasiun saat ini.
* Stasiun berikutnya.
* Stasiun transit.
* Stasiun tujuan.
* Stasiun setelah tujuan sebagai peringatan apabila pengguna terlewat.

## Panduan Transit

Saat pengguna perlu transit, tampilkan:

* Nama stasiun transit.
* Jumlah stasiun sebelum transit.
* Jalur berikutnya.
* Tujuan kereta berikutnya.
* Estimasi waktu transit.
* Arah perpindahan.
* Peron jika datanya tersedia.
* Peta sederhana area stasiun jika tersedia.

## Tombol Aksi

* Akhiri perjalanan.
* Ubah tujuan.
* Saya naik kereta lain.
* Bagikan perjalanan.
* Laporkan kondisi.
* Mode hemat baterai.
* Mode layar tetap menyala.

---

# 11. NOTIFIKASI PERJALANAN

Notifikasi harus tetap bekerja ketika aplikasi diminimalkan.

## Sebelum Berangkat

* Pengingat waktu berangkat.
* Kereta berikutnya.
* Keterlambatan jalur.
* Waktu berjalan menuju stasiun.
* Kereta terakhir.
* Perubahan jadwal.

## Saat Berada di Kereta

* Perjalanan berhasil dimulai.
* Stasiun berikutnya.
* Tiga stasiun sebelum tujuan.
* Dua stasiun sebelum tujuan.
* Satu stasiun sebelum tujuan.
* Bersiap untuk turun.
* Stasiun tujuan telah tiba.
* Waktunya transit.
* Jalur perjalanan berubah.
* Pengguna kemungkinan melewati tujuan.

## Bentuk Peringatan

Sediakan:

* Notifikasi teks.
* Suara.
* Getaran.
* Getaran panjang untuk tujuan.
* Text-to-speech opsional.
* Mode senyap.
* Mode hanya getar.
* Mode headset.

Pengguna dapat mengatur peringatan pada:

* Lima stasiun sebelumnya.
* Tiga stasiun sebelumnya.
* Dua stasiun sebelumnya.
* Satu stasiun sebelumnya.
* Berdasarkan waktu, misalnya lima menit sebelum tiba.

---

# 12. STASIUN TERDEKAT

Gunakan lokasi perangkat untuk mencari stasiun terdekat.

Tampilkan:

* Nama stasiun.
* Jarak.
* Waktu berjalan kaki.
* Jalur yang tersedia.
* Jam operasional.
* Fasilitas.
* Tingkat kepadatan jika tersedia.
* Status layanan.
* Akses transportasi lanjutan.
* Pintu masuk terdekat jika datanya tersedia.

Sediakan mode daftar dan mode peta.

---

# 13. DETAIL STASIUN

Setiap stasiun memiliki halaman detail.

## Informasi Stasiun

* Nama lengkap.
* Kode stasiun.
* Jalur yang melayani.
* Lokasi.
* Peta.
* Jadwal keberangkatan berikutnya.
* Status operasional.
* Fasilitas.
* Toilet.
* Musala.
* Lift.
* Eskalator.
* Area parkir.
* Minimarket.
* ATM.
* Loket.
* Vending machine.
* Akses kursi roda.
* Tempat pengisian daya jika tersedia.
* Area penjemputan transportasi online.
* Pintu masuk dan keluar jika datanya tersedia.

## Transportasi Terintegrasi

Tampilkan koneksi:

* MRT.
* LRT.
* TransJakarta.
* Mikrotrans.
* Bus.
* Angkot.
* Kereta Bandara.
* Transportasi online.
* Berjalan kaki.
* Sepeda.

---

# 14. DESTINASI DI SEKITAR STASIUN

Buat fitur “Jelajahi Sekitar Stasiun”.

## Kategori Destinasi

* Tempat wisata.
* Pusat perbelanjaan.
* Kuliner.
* Rumah sakit.
* Apotek.
* Hotel.
* Taman.
* Museum.
* Tempat ibadah.
* ATM.
* Minimarket.
* Kantor pemerintahan.
* Kampus.
* Sekolah.
* Area bisnis.
* Ruang publik.
* Toilet umum.

## Informasi Destinasi

* Nama.
* Foto jika tersedia dan berizin.
* Kategori.
* Jarak dari stasiun.
* Estimasi berjalan kaki.
* Jam operasional jika tersedia.
* Rating jika sumber data mengizinkan.
* Deskripsi singkat.
* Akses transportasi.
* Tombol navigasi.
* Tombol simpan.
* Tombol bagikan.

## Rekomendasi

Sediakan daftar:

* Terdekat dari stasiun.
* Populer.
* Ramah keluarga.
* Gratis dikunjungi.
* Cocok untuk anak.
* Cocok untuk akhir pekan.
* Tempat makan dekat stasiun.
* Destinasi yang dapat dicapai tanpa kendaraan tambahan.

Data destinasi harus berasal dari sumber terbuka, partner, atau database kurasi milik TK.

---

# 15. PERJALANAN MULTIMODA

Trip planner harus dapat menggabungkan:

* Berjalan kaki.
* KRL.
* MRT.
* LRT.
* TransJakarta.
* Mikrotrans.
* Bus.
* Angkot.
* Transportasi online.
* Sepeda.

Contoh perjalanan:

1. Berjalan 400 meter ke Stasiun Bogor.
2. Naik Commuter Line menuju Jakarta Kota.
3. Turun di Stasiun Manggarai.
4. Transit ke Commuter Line menuju Tanah Abang.
5. Turun di Sudirman.
6. Berjalan ke Stasiun Dukuh Atas.
7. Melanjutkan dengan MRT atau TransJakarta.
8. Berjalan menuju lokasi tujuan.

## Detail Integrasi Moda

Tampilkan:

* Waktu tunggu.
* Waktu berjalan.
* Waktu di kendaraan.
* Jumlah transit.
* Estimasi biaya.
* Estimasi tiba.
* Risiko keterlambatan.
* Alternatif perjalanan.
* Waktu terakhir untuk melakukan perjalanan.

Untuk transportasi online, gunakan deep link resmi jika tersedia. Jangan mengambil harga tanpa izin API.

---

# 16. WIDGET LAYAR UTAMA ANDROID

Buat widget Android native yang terhubung dengan Flutter.

Widget harus tetap menampilkan data terakhir meskipun aplikasi tidak dibuka.

## Widget 2×2 — Kereta Berikutnya

Tampilkan:

* Stasiun favorit.
* Waktu kereta berikutnya.
* Tujuan kereta.
* Status keterlambatan.
* Tombol refresh.

## Widget 4×2 — Rute Harian

Tampilkan:

* Rute favorit.
* Tiga jadwal berikutnya.
* Status jalur.
* Estimasi waktu berangkat dari rumah.

## Widget Perjalanan Aktif

Tampilkan:

* Stasiun sekarang.
* Stasiun berikutnya.
* Jumlah stasiun tersisa.
* Estimasi tiba.
* Progress perjalanan.
* Tombol buka perjalanan.

## Widget Status Jalur

Tampilkan beberapa jalur:

* Normal.
* Terlambat.
* Gangguan.
* Informasi belum tersedia.

Widget harus:

* Bisa diubah ukurannya.
* Mendukung light mode dan dark mode.
* Memiliki refresh manual.
* Tidak melakukan refresh GPS berlebihan.
* Membuka halaman aplikasi yang sesuai saat ditekan.
* Menampilkan waktu terakhir diperbarui.
* Memiliki empty state ketika rute favorit belum dipilih.

---

# 17. RUTE FAVORIT DAN KOMUTER RUTIN

Pengguna dapat menyimpan:

* Stasiun rumah.
* Stasiun kantor.
* Stasiun kampus.
* Rute pulang.
* Tujuan wisata.
* Jadwal rutin.

## Smart Commute

Contoh pengaturan:

* Senin–Jumat.
* Berangkat pukul 06.30.
* Pulang pukul 17.30.
* Beri tahu 30 menit sebelumnya.
* Beri tahu apabila ada gangguan.
* Beri tahu apabila harus berangkat lebih awal.

Aplikasi dapat menyarankan waktu berangkat berdasarkan:

* Jadwal.
* Waktu berjalan ke stasiun.
* Waktu transit.
* Gangguan layanan.
* Riwayat perjalanan lokal.
* Preferensi pengguna.

---

# 18. LAPORAN PENGGUNA

Pengguna dapat mengirim laporan mengenai:

* Kereta padat.
* AC bermasalah.
* Fasilitas stasiun bermasalah.
* Lift atau eskalator tidak berfungsi.
* Perubahan peron.
* Keterlambatan.
* Barang tertinggal.
* Kondisi darurat.
* Informasi yang tidak sesuai.

Laporan komunitas harus:

* Memiliki waktu kedaluwarsa.
* Tidak langsung dianggap sebagai informasi resmi.
* Memiliki label “Laporan pengguna”.
* Dapat diverifikasi oleh pengguna lain atau admin.
* Memiliki mekanisme pelaporan konten.
* Tidak menampilkan identitas pelapor secara publik.

Untuk kondisi darurat, tampilkan kanal bantuan resmi dan jangan menggantikan layanan darurat.

---

# 19. MODE OFFLINE

Saat internet tidak tersedia, aplikasi tetap dapat menampilkan:

* Daftar stasiun.
* Peta jalur sederhana.
* Jadwal terakhir yang tersimpan.
* Rute favorit.
* Detail perjalanan yang sudah disimpan.
* Informasi fasilitas dasar.
* Data tujuan yang telah disimpan.

Semua data offline harus memiliki:

* Tanggal terakhir diperbarui.
* Peringatan bahwa perubahan terbaru mungkin belum tersedia.
* Tombol coba sambungkan kembali.

---

# 20. NAVIGASI APLIKASI

Gunakan bottom navigation dengan lima menu:

1. Beranda.
2. Jadwal.
3. Peta.
4. Jelajahi.
5. Profil.

Ketika perjalanan sedang aktif, tampilkan mini-player perjalanan di atas bottom navigation.

Mini-player menampilkan:

* Stasiun berikutnya.
* Tujuan.
* Jumlah stasiun tersisa.
* Tombol buka perjalanan.

---

# 21. DAFTAR HALAMAN

Buat seluruh halaman berikut:

1. Splash screen.
2. Onboarding.
3. Permintaan izin lokasi.
4. Permintaan izin notifikasi.
5. Beranda.
6. Pencarian stasiun.
7. Pemilih lokasi.
8. Hasil perjalanan.
9. Detail perjalanan.
10. Jadwal stasiun.
11. Jadwal kereta.
12. Peta real-time.
13. Detail kereta.
14. Konfirmasi deteksi naik KRL.
15. Perjalanan aktif.
16. Panduan transit.
17. Perjalanan selesai.
18. Riwayat perjalanan.
19. Stasiun terdekat.
20. Detail stasiun.
21. Fasilitas stasiun.
22. Jelajahi destinasi.
23. Detail destinasi.
24. Rute multimoda.
25. Status layanan.
26. Detail gangguan.
27. Rute favorit.
28. Pengaturan perjalanan rutin.
29. Pusat notifikasi.
30. Pengaturan notifikasi.
31. Pengaturan lokasi.
32. Pengaturan aksesibilitas.
33. Pengaturan widget.
34. Profil.
35. Login opsional.
36. Daftar akun opsional.
37. Privasi.
38. Tentang aplikasi.
39. Bantuan.
40. Kirim laporan.
41. Mode offline.
42. Halaman error.
43. Halaman data tidak tersedia.
44. Halaman pembaruan aplikasi.

---

# 22. DESAIN VISUAL

Gunakan desain modern, ramah, bersih, mudah dibaca, dan tidak terlalu ramai.

Identitas visual harus terasa seperti:

* Transportasi publik modern.
* Pendamping perjalanan yang ramah.
* Aman dan dapat dipercaya.
* Informatif tetapi tidak kaku.
* Cocok untuk semua usia.

Jangan menyalin desain atau branding aplikasi transportasi lain.

## Palet Warna Utama

Gunakan:

* Primary Navy: `#102A43`
* Primary Blue: `#1677FF`
* Soft Blue: `#EAF3FF`
* Accent Coral: `#FF5A5F`
* Success Green: `#16A36A`
* Warning Amber: `#F59E0B`
* Error Red: `#D92D20`
* Background Light: `#F7F9FC`
* Surface Light: `#FFFFFF`
* Text Primary: `#172B4D`
* Text Secondary: `#62748A`
* Border: `#DCE3EC`

Dark mode:

* Background Dark: `#09131F`
* Surface Dark: `#112235`
* Surface Elevated: `#183149`
* Text Primary Dark: `#F5F8FC`
* Text Secondary Dark: `#B9C7D6`
* Border Dark: `#29445D`

Aturan warna:

* Jangan menggunakan merah dan hijau sebagai satu-satunya pembeda.
* Pastikan rasio kontras teks memenuhi standar aksesibilitas.
* Warna jalur transportasi hanya digunakan sebagai indikator tambahan.
* Gunakan ruang putih yang cukup.
* Hindari gradient berlebihan.
* Maksimal satu warna aksen dominan dalam satu komponen.

## Tipografi

Gunakan:

**Plus Jakarta Sans**

Fallback:

* Inter.
* Roboto.
* Sans-serif.

Skala font:

* Display: 32 px, bold.
* Heading 1: 28 px, bold.
* Heading 2: 24 px, semibold.
* Heading 3: 20 px, semibold.
* Body Large: 16 px.
* Body: 14 px.
* Caption: 12 px.
* Minimum teks penting: 14 px.

Gunakan tinggi baris yang nyaman dan hindari teks abu-abu terlalu muda.

## Bentuk Komponen

* Radius kartu: 16–20 px.
* Radius tombol: 12–16 px.
* Tinggi tombol utama minimal 48 px.
* Area sentuh minimal 48×48 px.
* Bayangan tipis.
* Ikon sederhana.
* Bottom sheet untuk detail singkat.
* Full page untuk informasi kompleks.

---

# 23. ANIMASI DAN MOTION

Semua halaman boleh memiliki animasi, tetapi harus ringan.

Gunakan:

* Flutter implicit animations.
* AnimatedSwitcher.
* AnimatedContainer.
* Hero transition.
* TweenAnimationBuilder.
* CustomPainter untuk jalur sederhana.
* Rive atau Lottie hanya untuk elemen tertentu.
* Skeleton loading ringan.
* Animasi progress perjalanan.
* Pergerakan ikon kereta secara halus.
* Bottom sheet transition.
* Microinteraction pada tombol dan pilihan.

Durasi:

* Microinteraction: 100–180 ms.
* Transisi komponen: 180–250 ms.
* Transisi halaman: 250–350 ms.

Ketentuan:

* Target 60 FPS.
* Jangan menjalankan animasi ketika komponen tidak terlihat.
* Hentikan animasi kompleks pada mode hemat baterai.
* Sediakan pengaturan “Kurangi Animasi”.
* Hormati pengaturan reduce motion perangkat.
* Hindari background video.
* Hindari blur berlebihan.
* Hindari banyak animasi berjalan bersamaan.

---

# 24. ARSITEKTUR TEKNIS FLUTTER

Gunakan:

* Flutter stable terbaru.
* Dart dengan null safety.
* Material 3.
* Feature-first architecture.
* Clean Architecture secukupnya.
* Riverpod untuk state management.
* GoRouter untuk navigasi.
* Dio untuk HTTP client.
* Freezed dan json_serializable untuk model.
* Drift untuk database lokal.
* Secure Storage untuk token.
* Firebase Cloud Messaging untuk push notification.
* Flutter Local Notifications untuk notifikasi lokal.
* MapLibre untuk peta.
* Geolocator atau implementasi native untuk lokasi.
* Native Android geofencing.
* Native Android Activity Recognition.
* WorkManager untuk sinkronisasi terjadwal.
* WebSocket atau Supabase Realtime untuk data real-time.
* Sentry atau Firebase Crashlytics untuk error monitoring jika tetap berada pada paket gratis.

Jangan memasang package yang memiliki fungsi sama tanpa alasan.

---

# 25. STRUKTUR PROYEK

Gunakan struktur:

```text
lib/
  app/
    app.dart
    router/
    theme/
    config/
  core/
    constants/
    errors/
    network/
    database/
    location/
    notifications/
    permissions/
    utils/
    widgets/
  features/
    onboarding/
    home/
    schedule/
    stations/
    live_map/
    trip_planner/
    active_trip/
    nearby_places/
    multimodal/
    service_alerts/
    favorites/
    commute/
    history/
    reports/
    widgets/
    profile/
    settings/
  data/
    providers/
    repositories/
    models/
    mappers/
  domain/
    entities/
    repositories/
    usecases/
```

Setiap fitur minimal memiliki:

```text
data/
domain/
presentation/
```

Gunakan pemisahan yang masuk akal. Jangan membuat abstraksi berlebihan.

---

# 26. BACKEND

Gunakan Supabase free tier untuk MVP.

Fitur backend:

* PostgreSQL.
* Authentication opsional.
* Anonymous session.
* Row Level Security.
* Realtime.
* Edge Functions.
* Scheduled jobs jika tersedia.
* Penyimpanan konfigurasi.
* Data stasiun.
* Data jalur.
* Data jadwal.
* Service alerts.
* Data destinasi.
* Rute favorit tersinkronisasi.
* Device token.
* Preferensi notifikasi.
* Laporan pengguna.

Aplikasi harus tetap dapat digunakan tanpa login.

Login hanya diperlukan untuk:

* Sinkronisasi lintas perangkat.
* Menyimpan favorit ke cloud.
* Menyimpan riwayat cloud.
* Mengirim laporan.
* Mengelola profil.

---

# 27. MODEL DATABASE

Buat tabel berikut:

## users

* id.
* display_name.
* email.
* avatar_url.
* created_at.
* updated_at.

## user_preferences

* user_id.
* language.
* theme.
* reduce_motion.
* notification_enabled.
* vibration_enabled.
* sound_enabled.
* destination_alert_stops.
* location_mode.
* analytics_consent.

## operators

* id.
* name.
* operator_type.
* logo_url.
* website.
* data_source_type.
* is_active.

## lines

* id.
* operator_id.
* code.
* name.
* color.
* text_color.
* transport_mode.
* is_active.

## stations

* id.
* code.
* name.
* latitude.
* longitude.
* address.
* timezone.
* wheelchair_accessible.
* facilities.
* is_active.

## station_lines

* station_id.
* line_id.
* stop_order.
* platform_information.

## trips

* id.
* external_trip_id.
* line_id.
* service_id.
* headsign.
* direction_id.
* trip_number.
* data_source.
* service_date.

## stop_times

* id.
* trip_id.
* station_id.
* stop_sequence.
* scheduled_arrival.
* scheduled_departure.
* pickup_type.
* drop_off_type.

## vehicle_positions

* id.
* trip_id.
* vehicle_id.
* latitude.
* longitude.
* bearing.
* speed.
* current_station_id.
* next_station_id.
* status.
* recorded_at.
* source.
* accuracy_status.

## trip_updates

* id.
* trip_id.
* station_id.
* arrival_delay_seconds.
* departure_delay_seconds.
* predicted_arrival.
* predicted_departure.
* updated_at.

## service_alerts

* id.
* operator_id.
* line_id.
* station_id.
* title.
* description.
* severity.
* starts_at.
* ends_at.
* source.
* is_official.

## transfer_rules

* id.
* from_station_id.
* to_station_id.
* minimum_transfer_seconds.
* walking_distance.
* accessibility_notes.
* instructions.

## nearby_places

* id.
* station_id.
* name.
* category.
* latitude.
* longitude.
* distance_meters.
* walking_duration_minutes.
* address.
* description.
* image_url.
* source.
* source_external_id.
* last_verified_at.

## user_favorites

* id.
* user_id.
* favorite_type.
* station_id.
* origin_station_id.
* destination_station_id.
* place_id.
* label.

## commute_plans

* id.
* user_id.
* name.
* origin_station_id.
* destination_station_id.
* active_days.
* departure_time.
* return_time.
* notify_before_minutes.
* is_active.

## trip_sessions

* id.
* user_id.
* planned_trip_id.
* matched_trip_id.
* origin_station_id.
* destination_station_id.
* started_at.
* ended_at.
* detection_method.
* confidence_score.
* status.
* location_upload_consent.

## device_tokens

* id.
* user_id.
* device_id.
* fcm_token.
* platform.
* last_active_at.

## notification_logs

* id.
* user_id.
* trip_session_id.
* notification_type.
* station_id.
* sent_at.
* opened_at.

## user_reports

* id.
* user_id.
* report_type.
* line_id.
* station_id.
* trip_id.
* description.
* media_url.
* latitude.
* longitude.
* status.
* expires_at.
* created_at.

Buat migration SQL lengkap, index, foreign key, trigger `updated_at`, dan Row Level Security.

---

# 28. DATA PROVIDER LAYER

Buat interface provider berikut:

```dart
abstract interface class TransitScheduleProvider {
  Future<List<TransitTrip>> searchTrips(TripSearchQuery query);
  Future<List<Departure>> getStationDepartures(
    String stationId,
    DateTime time,
  );
}

abstract interface class TransitRealtimeProvider {
  Stream<List<VehiclePosition>> watchVehiclePositions();
  Stream<List<TripUpdate>> watchTripUpdates();
  Stream<List<ServiceAlert>> watchServiceAlerts();
}

abstract interface class PlacesProvider {
  Future<List<NearbyPlace>> getNearbyPlaces(
    double latitude,
    double longitude,
    PlaceFilter filter,
  );
}
```

Sediakan adapter untuk:

* API resmi operator.
* GTFS Schedule.
* GTFS-Realtime.
* Database internal.
* Mock provider untuk development.
* Cached provider untuk offline.

Sistem harus dapat mengganti provider menggunakan konfigurasi environment tanpa mengubah UI.

---

# 29. SISTEM ROUTING

Gunakan graph perjalanan yang mempertimbangkan:

* Stop sequence.
* Waktu keberangkatan.
* Waktu tiba.
* Transfer.
* Minimum transfer time.
* Walking connection.
* Service calendar.
* Gangguan.
* Keterlambatan.
* Preferensi pengguna.

Buat nilai biaya perjalanan berdasarkan kombinasi:

```text
total_cost =
  travel_time
  + waiting_penalty
  + transfer_penalty
  + walking_penalty
  + disruption_penalty
```

Tampilkan minimal tiga alternatif perjalanan apabila tersedia.

---

# 30. ALGORITMA ACTIVE TRIP

Gunakan state machine:

```text
IDLE
NEAR_STATION
AT_STATION
POSSIBLE_BOARDING
CONFIRMING_TRIP
ON_BOARD
APPROACHING_TRANSFER
TRANSFERRING
APPROACHING_DESTINATION
ARRIVED
MISSED_DESTINATION
COMPLETED
CANCELLED
```

## Ketentuan

* Perubahan state harus disimpan secara lokal.
* State dapat dipulihkan setelah aplikasi ditutup.
* Perjalanan aktif menggunakan foreground service Android.
* Foreground service menampilkan notifikasi persisten.
* Frekuensi lokasi harus adaptif.
* Ketika jauh dari stasiun dan tidak ada perjalanan, hentikan tracking intensif.
* Gunakan geofence untuk stasiun penting.
* Jangan mendaftarkan seluruh stasiun sekaligus.
* Daftarkan geofence berdasarkan lokasi dan rute aktif.
* Jika GPS tidak akurat, gunakan jadwal dan urutan stasiun sebagai bantuan.
* Jika confidence turun, minta konfirmasi pengguna.
* Jangan otomatis mengakhiri perjalanan hanya karena GPS hilang di dalam bangunan atau terowongan.

---

# 31. STRATEGI HEMAT BATERAI

Gunakan beberapa mode:

## Idle

* Tidak ada perjalanan aktif.
* Tidak mengambil lokasi terus-menerus.
* Hanya sinkronisasi ringan.
* Geofence stasiun terdekat jika pengguna mengaktifkan deteksi otomatis.

## Near Station

* Frekuensi lokasi sedang.
* Aktifkan pencocokan jadwal.
* Periksa aktivitas pengguna.

## Active Trip

* Gunakan update lokasi adaptif.
* Interval lebih cepat ketika bergerak.
* Interval lebih lambat ketika kereta berhenti.
* Gunakan jarak minimum.
* Gunakan sensor dan feed kendaraan untuk mengurangi ketergantungan GPS.

## Low Battery

* Kurangi frekuensi lokasi.
* Matikan animasi peta kompleks.
* Gunakan urutan stasiun dan estimasi jadwal.
* Informasikan bahwa akurasi dapat berkurang.

---

# 32. PRIVASI DAN KEAMANAN

Terapkan:

* HTTPS untuk seluruh API.
* Token disimpan di secure storage.
* Row Level Security.
* Validasi server-side.
* Rate limiting.
* App Check jika digunakan.
* Sanitasi laporan pengguna.
* Penghapusan metadata sensitif dari foto.
* Lokasi tidak disimpan ke server tanpa persetujuan.
* Riwayat perjalanan dapat dihapus.
* Akun dapat dihapus.
* Pengguna dapat mengekspor data.
* Data lokasi mentah memiliki masa retensi terbatas.
* Analytics dalam keadaan opt-in.
* Jangan mengirim data lokasi ke provider iklan.
* Jangan memasang SDK iklan.

Buat halaman privasi sederhana yang menjelaskan:

* Data yang dikumpulkan.
* Alasan pengumpulan.
* Penyimpanan.
* Penghapusan.
* Hak pengguna.
* Kontak pengelola aplikasi.

---

# 33. AKSESIBILITAS

Pastikan:

* Mendukung TalkBack.
* Semua ikon memiliki semantic label.
* Tidak mengandalkan warna saja.
* Dynamic text scaling.
* Tombol cukup besar.
* Kontras tinggi.
* Mode kurangi animasi.
* Mode getaran.
* Mode text-to-speech.
* Informasi jalur dibaca dalam urutan yang benar.
* Peta memiliki alternatif berbentuk daftar.
* Pengguna dapat memilih tampilan sederhana.

---

# 34. KINERJA

Targetkan:

* Cold start maksimal 2,5 detik pada perangkat menengah.
* Scroll stabil 60 FPS.
* Tidak ada jank pada halaman utama.
* Ukuran aplikasi awal diusahakan di bawah 50 MB.
* Cache dibatasi dan dapat dibersihkan.
* Gambar menggunakan ukuran yang sesuai.
* Peta tidak merender marker yang tidak terlihat.
* Gunakan clustering untuk marker.
* Jangan melakukan rebuild seluruh peta setiap menerima posisi baru.
* API memiliki timeout dan retry terkontrol.
* Gunakan pagination untuk riwayat dan destinasi.
* Hindari polling jika WebSocket tersedia.
* Update posisi peta harus di-throttle.

---

# 35. ERROR HANDLING

Buat error state untuk:

* Internet terputus.
* GPS mati.
* Izin lokasi ditolak.
* Izin lokasi latar belakang ditolak.
* Notifikasi ditolak.
* Feed real-time tidak tersedia.
* Jadwal gagal dimuat.
* Data kedaluwarsa.
* Tidak ada rute.
* Stasiun tidak ditemukan.
* Pengguna keluar dari jalur.
* Server sibuk.
* Aplikasi dalam mode offline.

Setiap error harus memiliki:

* Penjelasan manusiawi.
* Penyebab singkat.
* Tombol coba lagi.
* Alternatif tindakan.
* Jangan menampilkan stack trace kepada pengguna.

---

# 36. ADMIN PANEL

Buat admin panel web ringan untuk pengelola TK.

Fitur:

* Login admin.
* Dashboard.
* Kelola operator.
* Kelola jalur.
* Kelola stasiun.
* Import GTFS.
* Validasi feed.
* Kelola fasilitas.
* Kelola destinasi.
* Kelola service alerts.
* Moderasi laporan pengguna.
* Kelola notifikasi.
* Audit log.
* Monitoring sinkronisasi data.
* Status provider.
* Data terakhir diperbarui.
* Mode maintenance.
* Remote configuration.

Gunakan Supabase dan framework web ringan seperti Next.js apabila admin panel dibuat terpisah.

---

# 37. PENGUJIAN

Buat:

* Unit test.
* Widget test.
* Integration test.
* Repository test.
* Location state machine test.
* Routing algorithm test.
* Notification scheduling test.
* Database migration test.
* Offline test.
* Permission denial test.
* Background tracking test.
* App widget test.
* Deep link test.

## Skenario Penting

### Skenario 1

Pengguna mencari perjalanan Bogor menuju Sudirman, memilih perjalanan, naik kereta, transit jika diperlukan, dan menerima notifikasi sebelum tujuan.

### Skenario 2

Pengguna tidak memilih perjalanan tetapi memasuki stasiun dan naik KRL. Aplikasi mendeteksi kemungkinan perjalanan dan meminta konfirmasi.

### Skenario 3

GPS tidak akurat selama perjalanan. Aplikasi tetap menggunakan urutan stasiun dan jadwal tanpa memberikan informasi palsu.

### Skenario 4

Feed real-time berhenti. Aplikasi mengubah label menjadi estimasi dan menampilkan waktu pembaruan terakhir.

### Skenario 5

Pengguna melewati stasiun tujuan. Aplikasi memberi tahu dan menawarkan rute untuk kembali.

### Skenario 6

Pengguna mematikan internet. Perjalanan aktif tetap menampilkan data offline terakhir.

### Skenario 7

Pengguna menolak background location. Aplikasi tetap dapat digunakan tetapi menjelaskan bahwa notifikasi perjalanan mungkin terbatas.

### Skenario 8

Pengguna memasang widget tetapi belum memilih stasiun favorit. Widget menampilkan tombol konfigurasi.

---

# 38. ACCEPTANCE CRITERIA

Aplikasi dinyatakan memenuhi MVP apabila:

1. Pengguna dapat mencari stasiun.
2. Pengguna dapat melihat jadwal.
3. Pengguna dapat mencari perjalanan dari satu stasiun ke stasiun lain.
4. Pengguna dapat melihat rute dan transit.
5. Pengguna dapat menyimpan rute favorit.
6. Pengguna dapat memulai perjalanan aktif.
7. Pengguna dapat memilih stasiun tujuan.
8. Aplikasi menampilkan jumlah stasiun tersisa.
9. Aplikasi memberikan notifikasi sebelum tujuan.
10. Perjalanan aktif tetap berjalan ketika aplikasi diminimalkan.
11. Widget dapat menampilkan jadwal favorit.
12. Aplikasi memiliki mode offline.
13. Data memiliki waktu terakhir diperbarui.
14. Real-time dan estimasi dapat dibedakan.
15. Izin lokasi ditangani dengan benar.
16. Tidak ada tombol utama yang tidak berfungsi.
17. Tidak ada API key yang disimpan langsung di source code.
18. Tidak ada data operasional palsu yang ditampilkan sebagai data asli.
19. Light mode dan dark mode berfungsi.
20. Tampilan dapat digunakan dengan TalkBack.

---

# 39. TAHAP PENGEMBANGAN

## Tahap 1 — Foundation

* Setup Flutter.
* Tema.
* Routing.
* Database lokal.
* Network layer.
* Error handling.
* Environment configuration.
* Mock data.

## Tahap 2 — Jadwal dan Stasiun

* Daftar stasiun.
* Pencarian.
* Detail stasiun.
* Jadwal.
* Rute perjalanan.
* Favorit.

## Tahap 3 — Active Trip

* Pemilihan tujuan.
* Timeline stasiun.
* Foreground service.
* Notifikasi tujuan.
* State machine.
* Pemulihan perjalanan.

## Tahap 4 — Deteksi Otomatis

* Geofencing.
* Activity Recognition.
* Confidence score.
* Pencocokan kandidat kereta.
* Konfirmasi pengguna.

## Tahap 5 — Real-time

* GTFS-Realtime adapter.
* Vehicle positions.
* Trip updates.
* Service alerts.
* WebSocket.
* Fallback estimasi.

## Tahap 6 — Widget

* Widget jadwal.
* Widget rute harian.
* Widget perjalanan aktif.
* Sinkronisasi Flutter dengan Android native.

## Tahap 7 — Multimoda dan Destinasi

* Transportasi lanjutan.
* Walking route.
* Destinasi sekitar stasiun.
* Deep link transportasi online.

## Tahap 8 — Production Readiness

* Testing.
* Security.
* Privacy.
* Performance.
* Crash monitoring.
* Analytics opt-in.
* Dokumentasi.
* Build release.

---

# 40. OUTPUT YANG HARUS DIHASILKAN

Jangan hanya memberikan penjelasan atau contoh UI.

Hasilkan:

1. Struktur proyek lengkap.
2. Source code Flutter.
3. Android native code untuk widget dan foreground service.
4. Database migration Supabase.
5. Row Level Security.
6. Edge Functions jika diperlukan.
7. Model data.
8. Repository.
9. Provider.
10. State management.
11. Semua halaman.
12. Navigasi.
13. Tema light dan dark.
14. Notifikasi.
15. Geofencing.
16. Active trip state machine.
17. Widget Android.
18. Mode offline.
19. Mock transit provider.
20. GTFS import parser.
21. GTFS-Realtime adapter.
22. Unit test.
23. Widget test.
24. Integration test.
25. `.env.example`.
26. `README.md`.
27. Panduan setup.
28. Panduan menjalankan aplikasi.
29. Panduan build APK.
30. Panduan konfigurasi backend.
31. Sample data yang diberi label demo.
32. Daftar kebutuhan API resmi untuk produksi.

---

# 41. ATURAN IMPLEMENTASI

* Jangan menulis pseudocode untuk fitur utama.
* Jangan menggunakan tombol kosong.
* Jangan meninggalkan komentar TODO pada alur utama.
* Jangan menyimpan secret di aplikasi.
* Jangan membuat satu file terlalu besar.
* Jangan menggunakan data hardcode untuk produksi.
* Jangan mengabaikan kondisi loading dan error.
* Jangan meminta login sebelum pengguna dapat melihat jadwal.
* Jangan mengaktifkan background location tanpa penjelasan.
* Jangan menampilkan estimasi sebagai posisi real-time.
* Jangan menggunakan scraping sebagai arsitektur utama.
* Jangan menggunakan Google Maps apabila solusi open-source mencukupi.
* Pastikan semua package kompatibel.
* Gunakan dependency injection.
* Gunakan linting ketat.
* Gunakan immutable state.
* Pastikan aplikasi dapat dikompilasi.
* Berikan source code file demi file dengan path yang jelas.
* Setelah menyelesaikan satu fase, lanjutkan ke fase berikutnya tanpa mengubah arsitektur sebelumnya.
* Apabila output terbatas, prioritaskan kode yang dapat dijalankan, bukan penjelasan panjang.
* Setiap kode lanjutan harus konsisten dengan file yang telah dibuat sebelumnya.

Mulai dengan menampilkan:

1. Ringkasan arsitektur.
2. Diagram alur aplikasi.
3. Struktur folder.
4. Daftar dependencies.
5. Database schema.
6. Implementasi fase foundation.
7. Kemudian lanjutkan seluruh fase sampai aplikasi dapat dijalankan.
