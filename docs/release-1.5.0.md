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

## Urutan menuju 1 Desember (GAPEKA 2026 dengan satu tombol)

Skema saklar: jadwal GAPEKA disiapkan di set `gapeka2026` yang tersembunyi, lalu satu tombol di admin web (halaman
**Jadwal**) menggantinya, tanpa build ulang. Detail dan perintah ada di `supabase/data/gapeka-2026/README.md`.

1. **Deploy Patungan** sudah dilakukan. Tes satu donasi kecil (Rp10.000) dari aplikasi di mode Mayar dan satu di mode GoPay.
2. **Rilis aplikasi 1.5.0** (Play Console) dan tunggu pengguna memperbaruinya. Putuskan update wajib atau tidak
   (`min_supported_version_code`); rekomendasi: jangan wajib.
3. **Terapkan migrasi berurutan:** `20261118090000_gapeka_estimated_times.sql`, lalu `20261122090000_schedule_switch.sql`.
   Aman: perilaku tidak berubah (set `lama` tetap aktif). Sudah diuji di produksi dalam transaksi yang di-rollback.
   Lalu deploy admin web (halaman Jadwal, kolom "Set jadwal" di Impor GTFS).
4. **Import GAPEKA dengan `--schedule-set gapeka2026 --start-date 2026-12-01`** (KRL Jabodetabek, KRL Yogyakarta, lalu KCI/KAI
   setelah 1.5.0 beredar). Periksa jumlah di halaman Jadwal.
5. **Halaman Jadwal: "Jadwalkan 1 Desember 00:00 WIB"** pada set `gapeka2026`. Kalau ada masalah: "Aktifkan sekarang" pada set `lama`.
6. **Rotasi password database** (tercatat di `scripts/build-release.ps1` dan sempat tercetak di log sesi uji).

## Cara mengecek peta

- Naik trip dengan "Deteksi Otomatis Naik KRL" aktif, buka tab Peta. Kamera harus langsung mengikuti dan kereta tidak berhenti-lalu-loncat tiap 3-4 detik.
- Geser peta dengan tangan: kamera berhenti mengikuti, tombol "Ikuti keretaku" muncul.
- Dengan dua HP di kereta yang sama (atau satu HP dan data uji di `train_live`): kereta kedua tampil dengan tujuan, tanpa nama.
