# Naskah TTS pengingat antar kota

Tiga klip, satu per jarak sisa rel. Klipnya statis, jadi tidak menyebut nama
stasiun. Tulis angka sebagai kata (jangan "km"), supaya mesin TTS tidak keliru
membacanya.

| Berkas | Jarak | Naskah |
|---|---|---|
| `eta_km_30.wav` | 30 km | Tiga puluh kilometer lagi menuju stasiun tujuan. Mulai perhatikan perjalananmu. |
| `eta_km_15.wav` | 15 km | Lima belas kilometer lagi menuju stasiun tujuan. Saatnya merapikan barang bawaanmu. |
| `eta_km_10.wav` | 10 km | Sepuluh kilometer lagi menuju stasiun tujuan. Bersiap turun ya. Periksa kembali barang bawaan dan tempat dudukmu. |

Format: WAV, mono, 24 kHz, 16 bit (sama dengan klip lain). Jeda sekitar 0,3
detik di akhir. Jangan taruh bunyi bel di dalam klip: bel `alarm.mp3` diputar
aplikasi sendiri setelah klip `eta_km_10` selesai.

Cara memasang klip baru (sudah dilakukan untuk 30, 15 dan 10 km):

1. Taruh sumbernya di `assets/` (mis. `30km.wav`), lalu salin ke
   `android/app/src/main/res/raw/eta_km_30.wav` dan
   `ios/Runner/Sounds/eta_km_30.wav` (ulangi untuk 15 dan 10).
2. Tambahkan `@raw/eta_km_30,@raw/eta_km_15,@raw/eta_km_10` ke `tools:keep` di
   `android/app/src/main/res/raw/keep.xml`.
3. Isi `_bundledIntercityKmClips` di `lib/core/notifications/alert_audio_plan.dart`
   dengan `{30, 15, 10}`.
