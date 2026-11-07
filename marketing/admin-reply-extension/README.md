# Admin Teman Kereta: asisten balas komentar (Chrome, MV3)

Membantu admin membalas komentar di Instagram, Threads, TikTok, YouTube, Facebook, dan X.
Komentar soal kebablasan/ketiduran dibalas dengan empati lalu soft selling Alarm Sisa Stasiun.
Ekstensi **tidak pernah mengirim otomatis**: admin memeriksa dan menekan kirim sendiri.

## Pasang
1. `chrome://extensions` → aktifkan Developer mode → **Load unpacked** → pilih folder ini.
2. Buka **Pengaturan** ekstensi: isi Base URL (OpenAI-compatible, tanpa `/chat/completions`), API key, dan nama model; centang "Pakai AI"; klik **Tes koneksi AI** dan setujui izin domainnya.
3. API key disimpan hanya di `chrome.storage.local` browser itu.

## Pakai
Klik sebuah komentar (atau tombol Balas/Reply): panel membaca komentar, nama pengomentar, dan konteks videonya, lalu menyusun 3 saran. Baris "Dipahami" menunjukkan tafsir AI atas komentar. Cadangan: blok teks → klik kanan, atau `Alt+Shift+R`.

## Aturan balasan
- Kebablasan/ketiduran: empati + Alarm Sisa Stasiun + link. Jadwal/kepadatan/rute: sebut fitur relevan dengan ringan.
- Pujian, keluhan aplikasi, negatif, powerbank: tanpa jualan.
- Kecelakaan/korban/duka: tidak menyebut aplikasi atau link (dipaksa di kode, bukan hanya di prompt).
- Fakta fitur hanya dari landing page; tidak mengaku sebagai KAI.

## Berkas
`replies.js` (topik, template, prompt AI) · `background.js` (menu, panggilan AI, parser) · `content.js` (panel & pembaca komentar) · `options.*` (pengaturan).
