import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/tk_components.dart';
import '../support_links.dart';
import 'support_widgets.dart';

export 'report_page.dart' show ReportPage;

/// Bantuan: answers for problems that actually happen in this app, then a
/// direct path to "Laporkan masalah".
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Bantuan')),
      body: SupportPageBody(
        children: <Widget>[
          const SupportParagraph(
            'Jawaban untuk masalah yang paling sering muncul. '
            'Kalau belum ketemu, kirim laporan: log dari HP-mu ikut terkirim supaya penyebabnya lebih cepat ketemu.',
            muted: true,
          ),
          const SupportSectionLabel('Peringatan dan notifikasi'),
          const SupportFaqTile(
            question: 'Peringatan stasiun tujuan tidak muncul saat layar mati',
            answer:
                'Ada tiga hal yang perlu aktif. Pertama, izin lokasi "Selalu izinkan". '
                'Kedua, izin notifikasi. Ketiga, Teman Kereta dibebaskan dari hemat baterai. '
                'Semuanya ada di Profil, Pengaturan lokasi, lengkap dengan tombol pintasnya. '
                'Pada HP Xiaomi, Oppo, Realme, dan Vivo, buka juga pengaturan khusus merek yang muncul di halaman itu '
                'dan izinkan aplikasi berjalan di latar belakang.',
          ),
          const SupportFaqTile(
            question: 'Suara pengumuman tidak terdengar',
            answer:
                'Buka Profil, Tes suara peringatan, lalu ketuk salah satu nada. Kalau tes itu juga diam, '
                'cek volume media, pastikan suara notifikasi di Profil, Pengaturan notifikasi tidak dimatikan, '
                'dan mode jangan ganggu tidak aktif. Suara bicara memakai mesin teks-ke-ucapan bawaan HP, '
                'jadi paket suara Bahasa Indonesia perlu terpasang di pengaturan Android.',
          ),
          const SupportFaqTile(
            question: 'Kapan lokasi dipakai di latar belakang?',
            answer:
                'Hanya setelah kamu memilih Mulai perjalanan. Layanan berhenti saat perjalanan selesai atau dibatalkan, '
                'dan notifikasi perjalanan aktif tampil selama layanan berjalan.',
          ),
          const SupportFaqTile(
            question: 'Apa itu Deteksi otomatis naik KRL?',
            answer:
                'Pilihan di Profil yang mengenali kamu sedang naik kereta dan menawarkan memulai perjalanan. '
                'Kalau aktif, posisimu dikirim sesekali selama perjalanan supaya penumpang lain bisa melihat posisi kereta. '
                'Posisi itu digabung dengan laporan penumpang lain dan tidak pernah ditampilkan sebagai posisimu. '
                'Pilihan ini mati secara bawaan.',
          ),
          const SupportSectionLabel('Jadwal dan peta'),
          const SupportFaqTile(
            question: 'Jadwal berbeda dengan kenyataan di stasiun',
            answer:
                'Jadwal berasal dari data jadwal KRL Jabodetabek yang disimpan di server Teman Kereta, '
                'bukan siaran langsung dari KAI Commuter. Perubahan mendadak, gangguan, atau jadwal baru bisa belum masuk. '
                'Kalau ada yang salah, kirim laporan dengan jenis "Jadwal salah" dan sebutkan stasiun, jam, serta lintasnya.',
          ),
          const SupportFaqTile(
            question: 'Dari mana posisi kereta di peta?',
            answer:
                'Perkiraan dari jadwal, ditambah posisi penumpang lain yang mengaktifkan Deteksi otomatis naik KRL. '
                'Itu bukan data langsung dari operator, jadi bisa meleset beberapa menit.',
          ),
          const SupportSectionLabel('Akun dan forum'),
          const SupportFaqTile(
            question: 'Cara mengikuti pengguna lain',
            answer:
                'Buka Profil, Cari pengguna, lalu ketuk Ikuti di profilnya. Tombol Ikuti juga ada di postingan forum. '
                'Di Forum, tab Mengikuti hanya menampilkan postingan dari orang yang kamu ikuti.',
          ),
          const SupportFaqTile(
            question: 'Melaporkan postingan atau memblokir pengguna',
            answer:
                'Ketuk Opsi postingan di pojok kartu, lalu pilih Laporkan atau Blokir pengguna. '
                'Daftar orang yang kamu blokir ada di Profil, Pengguna yang diblokir, dan bisa dibuka lagi dari sana.',
          ),
          const SupportFaqTile(
            question: 'Lupa kata sandi',
            answer:
                'Di halaman masuk, ketuk Lupa kata sandi lalu isi email akunmu. Kami mengirim link untuk membuat kata sandi baru. Cek juga folder Spam.',
          ),
          const SupportFaqTile(
            question: 'Menghapus akun',
            answer:
                'Buka Profil, bagian Akun, lalu Hapus akun. Akun dan data yang tersimpan padanya ikut terhapus. '
                'Kalau tidak bisa membuka aplikasi, pakai halaman penghapusan akun di situs web kami.',
          ),
          const SizedBox(height: 16),
          TkCard(
            tone: TkCardTone.soft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Masalahmu belum terjawab?', style: textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Kirim laporan dari aplikasi. Log dan info perangkat ikut terkirim, jadi kamu tidak perlu menjelaskan setelan HP satu per satu.',
                  style: textTheme.bodyMedium?.copyWith(color: tk.textMuted),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/report'),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Laporkan masalah'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => openExternal(
                      context,
                      SupportLinks.mailto,
                      fallbackLabel: SupportLinks.supportEmail,
                    ),
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: const Text(SupportLinks.supportEmail),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Privasi: a short readable summary. The full policy lives on the website.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privasi')),
      body: SupportPageBody(
        children: <Widget>[
          const SupportParagraph(
            'Ringkasan data apa yang kami proses, untuk apa, dan pilihanmu. '
            'Yang berlaku mengikat adalah kebijakan lengkap di situs web.',
            muted: true,
          ),
          const SupportSectionLabel('Yang kami proses'),
          const SupportInfoGroup(
            children: <Widget>[
              SupportInfoBlock(
                icon: Icons.location_on_outlined,
                title: 'Lokasi',
                body:
                    'Dipakai untuk mencari stasiun terdekat dan memandu perjalanan aktif, termasuk saat layar mati. '
                    'Posisimu hanya dikirim ke server kalau Deteksi otomatis naik KRL aktif, dan itu mati secara bawaan.',
              ),
              SupportInfoBlock(
                icon: Icons.account_circle_outlined,
                title: 'Akun dan profil',
                body:
                    'Email, nama tampilan, dan username. Stasiun rumah, kantor, dan rute favorit tersimpan di akunmu. '
                    'Kata sandi disimpan terenkripsi oleh penyedia autentikasi dan tidak bisa kami baca.',
              ),
              SupportInfoBlock(
                icon: Icons.forum_outlined,
                title: 'Forum dan fitur sosial',
                body:
                    'Postingan, komentar, foto, dan siapa yang kamu ikuti terlihat oleh pengguna lain. '
                    'Laporan dan blokirmu hanya terlihat olehmu dan moderator.',
              ),
              SupportInfoBlock(
                icon: Icons.notifications_none_rounded,
                title: 'Token notifikasi',
                body:
                    'Pengenal perangkat untuk mengirim pemberitahuan gangguan layanan dan balasan forum.',
              ),
              SupportInfoBlock(
                icon: Icons.flag_outlined,
                title: 'Laporan masalah',
                body:
                    'Berisi pesanmu, info perangkat dan aplikasi, serta log aplikasi kalau kamu membiarkannya aktif. '
                    'Kata sandi, token, email, dan nomor telepon di log disamarkan. Email-mu ikut hanya jika kamu mencentangnya. '
                    'Laporan disimpan di server kami dan diteruskan ke support@temankereta.web.id lewat Cloudflare Email Service.',
              ),
            ],
          ),
          const SupportSectionLabel('Yang tetap di perangkatmu'),
          const SupportInfoGroup(
            children: <Widget>[
              SupportInfoBlock(
                icon: Icons.history_outlined,
                title: 'Riwayat perjalanan dan pengaturan',
                body:
                    'Tersimpan di HP-mu saja dan tidak dibagikan. Mencopot aplikasi menghapusnya.',
              ),
              SupportInfoBlock(
                icon: Icons.description_outlined,
                title: 'Log aplikasi',
                body:
                    'Catatan teknis singkat disimpan di HP-mu (sekitar 512 KB, yang lama ditimpa) dan hanya keluar kalau kamu mengirim laporan.',
              ),
            ],
          ),
          const SupportSectionLabel('Yang tidak kami lakukan'),
          const SupportInfoGroup(
            children: <Widget>[
              SupportInfoBlock(
                icon: Icons.block_flipped,
                title: 'Tanpa iklan dan pelacak analitik',
                body:
                    'Tidak ada SDK iklan atau analitik pihak ketiga, dan lokasimu tidak dijual. '
                    'Pelaporan crash otomatis tidak aktif; kalau suatu saat dinyalakan, halaman ini diperbarui lebih dulu.',
              ),
            ],
          ),
          const SupportSectionLabel('Hapus akun'),
          const SupportParagraph(
            'Buka Profil, bagian Akun, lalu ketuk Hapus akun. Akun dan data yang tersimpan padanya ikut terhapus. '
            'Kalau tidak bisa membuka aplikasi, minta penghapusan lewat halaman penghapusan akun di situs web atau email ke '
            '${SupportLinks.supportEmail}.',
            muted: true,
          ),
          const SizedBox(height: 8),
          const SupportSectionLabel('Pilihanmu'),
          const SupportParagraph(
            'Izin lokasi, aktivitas fisik, dan notifikasi bisa dicabut kapan saja di pengaturan Android. '
            'Fitur yang tidak butuh izin itu tetap jalan.',
            muted: true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  openExternal(context, Uri.parse(SupportLinks.privacyPolicy)),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Baca kebijakan lengkap'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  openExternal(context, Uri.parse(SupportLinks.deleteAccount)),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Halaman hapus akun'),
            ),
          ),
        ],
      ),
    );
  }
}
