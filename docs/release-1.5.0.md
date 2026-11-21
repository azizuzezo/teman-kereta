# Rilis 1.5.0+25

Berisi semua yang ada di 1.4.0 (GAPEKA 2026, menu Dukung Pengembang) ditambah navigasi peta yang mulus dan donasi.
1.4.0+24 belum pernah dirilis, jadi tidak ada versi yang dilewati: langsung pakai 1.5.0+25.

## Isi

| Area | Perubahan |
|---|---|
| Jadwal | GAPEKA 2026: 7 jaringan, jam asli di pencarian rute, tanda perkiraan dan fakultatif, Antar Kota per nomor KA (sudah ada di 1.4.0). |
| Peta | Kereta penumpang meluncur mulus per frame di atas rel, gerbong mengikuti tikungan, kamera mengikuti seperti navigasi (otomatis saat naik, tombol "Ikuti keretaku" bila ditinggalkan). |
| Peta | Kereta pengguna lain tampil semua, hanya arah dan tujuan ("ke Bogor"), tanpa nama. Bentuknya rangkaian KRL, bukan lingkaran. |
| Peta | Laporan posisi tiap 5 detik (dulu 20) dari fix pelacak native, tanpa panggilan GPS kedua. Kecepatan dan arah ikut dikirim. |
| Donasi | "Dukung Pengembang" di menu Profil dan kartu di layar perjalanan selesai. Popup di tengah layar: pilih nominal, QRIS tampil di dalam aplikasi, lunas terdeteksi otomatis. QRIS dan pencatatan dibuat Patungan Yuk! (donasi muncul di halaman dev seperti biasa). |

## Teks "Yang baru" untuk Play Console (di bawah 500 karakter)

```
Jadwal GAPEKA 2026 berlaku mulai 1 Desember.
Peta navigasi baru: kereta kamu bergerak mulus di atas rel, kamera mengikuti seperti navigator, dan kereta pengguna lain terlihat lengkap dengan arah dan tujuannya (tanpa nama).
Bentuk kereta kini KRL Commuter Line.
Dukung Pengembang lewat QRIS langsung di dalam aplikasi (menu Profil).
```

## Status sebelum rilis

- **Migrasi `20261121090000_train_live.sql`**: sudah diterapkan ke database hosted dan diverifikasi (tabel, trigger, cron prune, Realtime). Kolom baru dan batas laju 4 detik aktif; pagar geografi diperluas ke Jawa tengah-barat.
- **Build dan uji**: `flutter analyze` bersih untuk file yang diubah. Tes peta, perjalanan selesai, dan pelapor posisi lolos. Tes `track_motion` dan `vehicle_motion` baru ikut lolos. Empat tes lama gagal di luar area ini (`tmp_dump_test`, `tmp_pages_test`, `widget_test`). APK debug sudah dipasang dan dijalankan di emulator Android 35.
- **Migrasi GAPEKA `20261118090000_gapeka_estimated_times.sql`**: BELUM diterapkan, sengaja menunggu cutover.

## Yang masih harus dikerjakan

0. **Deploy Patungan Yuk! dulu, baru rilis aplikasi.** Dukungan di aplikasi memanggil `POST https://patungan.gifts/api/app/dev-donation` (kode baru di proyek `Patungan Yuk!`: `src/admin/donatePublic.js`, `src/admin/server.js`, `test/appDevDonation.test.js`; belum di-commit). Status bayar dibaca dari `GET /status/:trxId` yang sudah ada. Aplikasi juga membaca `GET /api/app/dev-donation/config` tiap 6 detik selama popup terbuka: begitu pilihan QRIS di Patungan diubah (GoPay atau Mayar), formnya ikut berubah. Mayar mewajibkan email dan nomor HP: email diambil dari akun yang masuk, nomor HP diminta sekali lalu disimpan di akun (`user_metadata.donor_phone`). Sebelum endpoint itu aktif, layar dukungan menampilkan pesan gagal dan tombol "Bayar lewat halaman web" (popup web), jadi tidak ada jalan buntu. Setelah deploy, tes satu donasi kecil sungguhan (Rp10.000) dari aplikasi.
1. **Putuskan update wajib atau tidak** (`min_supported_version_code`). Rekomendasi: jangan wajib, kecuali jadwal lama harus dimatikan di semua HP saat 1 Desember.
2. **Cutover database GAPEKA 28-30 November** sesuai `supabase/data/gapeka-2026/README.md` (langkah database dijalankan manual).
3. **Rotasi password database** (tercatat di `scripts/build-release.ps1` dan sempat tercetak di log sesi uji).
4. Unggah AAB ke Play Console, isi "Yang baru" di atas, dan tambahkan rilisnya di admin web (Rilis) bila memakai pembaruan dalam aplikasi.

## Cara mengecek peta

- Naik trip dengan "Deteksi Otomatis Naik KRL" aktif, buka tab Peta. Kamera harus langsung mengikuti dan kereta tidak berhenti-lalu-loncat tiap 3-4 detik.
- Geser peta dengan tangan: kamera berhenti mengikuti, tombol "Ikuti keretaku" muncul.
- Dengan dua HP di kereta yang sama (atau satu HP dan data uji di `train_live`): kereta kedua tampil dengan tujuan, tanpa nama.
