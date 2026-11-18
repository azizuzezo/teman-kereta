# CLAUDE.md

## Aturan main membuat video (Reels / short-form / promo)

Setiap kali membuat video (HyperFrames, Remotion, motion graphic, promo app,
Reels/TikTok/Shorts), ikuti skill pack Instagram di `.claude/skills/ig-*`
(sumber: github.com/Jakeschincariol/instagram-agent-skill) sebagai aturan
naskah dan struktur. Skill render (`hyperframes`, `remotion`, dll.) tetap
dipakai untuk produksi; skill `ig-*` menentukan *isi*-nya.

Urutan wajib:

1. **Hook dulu** (`/ig-reel`): tulis 3 hook dari formula berbeda di
   `.claude/skills/ig-reel/hooks.json`, skor dengan
   `python3 hookscore.py`, pakai yang tertinggi. Di bawah 50 = belum punya hook.
2. **Bentuk video**: 0-2s HOOK (ada gerak di frame pertama) → 2-7s STAKE →
   BODY satu ide per beat, frame berganti tiap beat → 3 detik terakhir PAYOFF +
   satu ajakan → baris terakhir mengulang satu kata dari hook (loop).
   Durasi 15-45 detik.
3. **Timing** (`beats.py naskah.txt --target <detik>`): perbaiki semua flag
   (hook > 3s, beat > 4s, beat tanpa hal konkret, tanpa loop) sebelum render.
4. **Teks di layar** ditulis terpisah dari narasi: maks 6 kata per kartu,
   kartu hook muncul di frame 1, caption body di-burn-in (orang nonton tanpa
   suara). Safe zone 1080x1920: tidak ada teks di atas y=230, di bawah y=1440,
   atau di 230px paling kanan.
5. **Humanize** (`/ig-human`): bersihkan narasi & teks dari em dash, kata
   klise, karakter tak terlihat sebelum ditunjukkan.
6. **Caption** (`/ig-caption`): 125 karakter pertama harus berdiri sendiri,
   satu ajakan, maks 5 hashtag, tanpa link di caption.

Aturan keras:

- Tanpa intro: tanpa salam, tanpa "di video ini", tanpa logo sting di awal.
- Angka, bukan kata sifat. Jangan pernah mengarang angka, testimoni, atau data
  pengguna Teman Kereta. Kalau belum ada angkanya, tulis `{{angka kamu}}` dan
  tandai.
- Satu ide per video; kalau ada dua, jadikan dua video.
- Tidak pernah memposting apa pun. Hasil akhir berupa file + blok siap-salin,
  user yang memposting.
- Profil suara: `~/.claude/instagram/voice.md` (isi dulu agar naskah sesuai
  gaya bicara).

Catatan: `hookscore.py` sudah ditambah kosakata Indonesia (stakes, angka,
kamu/-mu, imperatif; aslinya di `hookscore.py.orig`). Lexicon `ig-human`
masih bahasa Inggris. Untuk
naskah bahasa Indonesia, jalankan alatnya tetapi nilai hasilnya dengan akal
sehat, dan terapkan prinsip yang sama (spesifik, konkret, tanpa klise) secara
manual.
