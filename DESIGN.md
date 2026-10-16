# DESIGN.md — Teman Kereta

Arah visual aplikasi, panel admin, dan situs web. Sumber: keputusan pemilik produk (navy + merah brand dari logo TK).

**Design Read:** pendamping komuter KRL Jabodetabek untuk pengguna harian yang sering melihat layar sambil berdiri atau berjalan, bahasa visual papan informasi stasiun (tegas, terbaca dari jauh), dial **ENERGY 2 / RHYTHM 2 / MOTION 1**.

## Identitas

| Keputusan | Alasan satu baris |
|---|---|
| Navy `#17376B` sebagai warna utama | Warna logo; navy tua memberi kontras tinggi di luar ruangan dan terasa seperti papan stasiun. |
| Merah `#C81E28` sebagai satu-satunya aksen | Garis merah di badan kereta pada logo; dipakai hanya untuk momen penting (stasiun tujuan, peringatan, tombol utama perjalanan). |
| Latar terang `#F3F5F9`, bukan putih murni | Mengurangi silau di layar terang saat di peron. |
| Latar gelap `#0A111D`, bukan hitam murni | Navy-hitam menghindari halo pada teks, nyaman di kereta malam; primary di mode gelap diterangkan jadi `#8DB2F2` supaya lolos kontras. |
| Font PlusJakartaSans (sudah dibundel) | Angka lebar dan jelas; angka waktu memakai tabular figures agar tidak bergeser tiap detik. |
| Kartu: radius 20, tanpa bayangan, garis tipis | Hierarki dibuat oleh ukuran dan warna, bukan oleh elevasi; bayangan hanya untuk bottom sheet. |
| Tombol: radius 14, bukan pil | Pil dipakai hanya untuk chip status, jadi bentuk membedakan fungsi. |
| Motif identitas: **garis rute** (titik stasiun tersambung garis vertikal) | Mengulang timeline perjalanan di logo, kartu jadwal, rekap, dan kartu bagikan. |

## Tiga palet (pemilih tema)

Semua palet punya mode terang dan gelap dan lolos WCAG AA (diuji dengan skrip kontras).

1. **Navy KRL** (default): navy + merah.
2. **Biru Klasik**: biru `#1259C8` + koral, untuk pengguna yang terbiasa dengan tema lama.
3. **Hijau Stasiun**: hijau `#0B6347` + oranye bata.

## Aturan pakai

- Warna hanya lewat `context.tk.*` (ThemeExtension `TkColors`). Dilarang hex mentah di halaman.
- Teks sekunder memakai `tk.textMuted` (>= 4.5:1 di semua permukaan).
- Setiap layar punya satu titik fokus. Ukuran sentuh minimum 48dp.
- Setiap daftar punya state loading, kosong, dan error (`TkSkeleton`, `AppEmptyState`, `TkErrorState`).
- Gerak: hanya transisi fungsional (<= 220ms), hormati `reduceMotion`.
- Tidak ada angka atau klaim tanpa sumber data nyata.
