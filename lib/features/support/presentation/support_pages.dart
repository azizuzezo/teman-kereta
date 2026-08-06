import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/data_badges.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bantuan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          const DemoDataBanner(),
          const SizedBox(height: 16),
          Text('Pertanyaan umum', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const _Faq(
            question: 'Apakah jadwal ini real-time?',
            answer:
                'Belum. Build lokal memakai data demo dan estimasi jadwal. Setiap informasi diberi label sumber dan kesegaran.',
          ),
          const _Faq(
            question: 'Kapan lokasi latar belakang digunakan?',
            answer:
                'Hanya setelah kamu memilih Mulai perjalanan. Layanan berhenti saat perjalanan diselesaikan atau dibatalkan.',
          ),
          const _Faq(
            question: 'Apakah saya harus membuat akun?',
            answer:
                'Tidak. Mode awal menyimpan preferensi dan perjalanan aktif di perangkat.',
          ),
          const _Faq(
            question: 'Mengapa peta berbentuk skema?',
            answer:
                'Agar build lokal dapat diuji tanpa tile server, token peta, atau koneksi internet.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/report'),
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('Buat laporan lokal'),
          ),
        ],
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          const Icon(Icons.shield_outlined, size: 54),
          const SizedBox(height: 18),
          Text(
            'Tidak ada akun. Sebagian besar data tetap di perangkat.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Teman Kereta tidak meminta kamu mendaftar atau masuk. Halaman ini menjelaskan data apa saja yang diproses, mengapa, di mana disimpan, cara menghapusnya, hak kamu, dan cara menghubungi pengelola aplikasi — sesuai kondisi aplikasi yang sebenarnya, bukan versi lama.',
          ),
          const SizedBox(height: 28),

          _SectionHeading('Data yang dikumpulkan dan alasannya'),
          const _PrivacyItem(
            icon: Icons.location_on_outlined,
            title: 'Lokasi',
            description:
                'Dipakai untuk tiga hal: (1) pencarian "stasiun terdekat" — satu kali lokasi saat kamu membuka fiturnya, diproses di perangkat, tidak dikirim ke mana pun; (2) deteksi otomatis naik KRL — lewat geofence dan sensor aktivitas Android (masuk/keluar area stasiun, sedang di kendaraan/berjalan/diam), juga diproses di perangkat, bukan pelacakan lokasi berkelanjutan; (3) SELAMA perjalanan aktif berlangsung, jika "Deteksi otomatis naik KRL" di Pengaturan aktif, posisi GPS-mu dikirim ke server setiap ±20 detik agar pengguna lain bisa melihat posisi kereta yang genuinely real (bukan estimasi jadwal). Ini SATU-SATUNYA lokasi yang benar-benar meninggalkan perangkat, dan hanya terjadi saat perjalanan aktif — mengaktifkan/menonaktifkan pengaturan itu langsung menghentikannya. Laporan posisi dikirim anonim (tanpa akun, tanpa pengenal pribadi), tersimpan sebagai data mentah paling lama 10 menit sebelum dihapus otomatis, dan yang ditampilkan ke pengguna lain hanya posisi gabungan (rata-rata beberapa pelapor), bukan data mentah per orang.',
          ),
          const _PrivacyItem(
            icon: Icons.notifications_none_rounded,
            title: 'Notifikasi',
            description:
                'Seluruhnya dijadwalkan oleh sistem Android di perangkat (peringatan stasiun, transit, dsb). Tidak ada server push, jadi tidak ada data yang dikirim keluar untuk mengirim notifikasi.',
          ),
          const _PrivacyItem(
            icon: Icons.schedule_outlined,
            title: 'Jadwal dan data stasiun',
            description:
                'Secara default berasal dari feed GTFS yang dibundel langsung di dalam aplikasi — tidak perlu koneksi internet. Jika mode "Supabase" diaktifkan, aplikasi membaca data jadwal/stasiun dari server referensi secara anonim (tanpa akun, tanpa pengenal pribadi apa pun dikirim).',
          ),
          const _PrivacyItem(
            icon: Icons.flag_outlined,
            title: 'Laporan pengguna',
            description:
                'Laporan yang kamu tulis (mis. kepadatan, AC mati) disimpan hanya di perangkat ini. Belum ada server untuk mengirimnya keluar, jadi laporan tidak terlihat oleh siapa pun selain kamu sendiri saat ini.',
          ),
          const _PrivacyItem(
            icon: Icons.history_outlined,
            title: 'Riwayat perjalanan, favorit, preferensi',
            description:
                'Seluruhnya disimpan lokal (database on-device). Tidak ada sistem akun di aplikasi ini, jadi tidak ada profil yang tersimpan di server mana pun.',
          ),
          const _PrivacyItem(
            icon: Icons.bug_report_outlined,
            title: 'Laporan kerusakan aplikasi (crash)',
            description:
                'Kemampuannya ada di dalam aplikasi tetapi TIDAK aktif secara default — tidak ada tujuan pengiriman yang dikonfigurasi. Jika suatu saat diaktifkan, halaman ini akan diperbarui untuk menjelaskannya sebelum dipakai secara luas.',
          ),
          const _PrivacyItem(
            icon: Icons.block_flipped,
            title: 'Analitik dan iklan',
            description:
                'Tidak ada SDK analitik pihak ketiga dan tidak ada SDK iklan yang dipasang di aplikasi ini.',
          ),

          const SizedBox(height: 12),
          _SectionHeading('Penyimpanan'),
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Text(
              'Data pribadi (favorit, riwayat, preferensi, laporan) disimpan di database lokal perangkat (Drift/SQLite) dan SharedPreferences — tidak disinkronkan ke server mana pun karena tidak ada akun. Data referensi transit (jadwal, stasiun, jalur) bersifat publik/anonim dan dibaca dari server hanya-baca yang sama untuk semua pengguna. Laporan posisi GPS saat naik KRL (lihat "Lokasi" di atas) disimpan sementara di server dalam bentuk anonim, dihapus otomatis maksimal 10 menit setelah diterima, dan digabung menjadi satu posisi rata-rata per kereta sebelum ditampilkan ke siapa pun.',
            ),
          ),

          _SectionHeading('Penghapusan'),
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Text(
              'Karena tidak ada akun/server pribadi, menghapus SEMUA data cukup lewat Android: Pengaturan > Aplikasi > Teman Kereta > Hapus data (atau copot pemasangan aplikasi). Ini menghapus favorit, riwayat, preferensi, dan laporan lokal sekaligus — tidak ada langkah tambahan di server yang perlu diminta.',
            ),
          ),

          _SectionHeading('Hak kamu'),
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Text(
              'Kamu dapat mencabut izin lokasi, izin aktivitas fisik, dan izin notifikasi kapan pun lewat Pengaturan Android — aplikasi tetap bisa dipakai dengan fitur yang menyesuaikan (lihat Bantuan). Karena tidak ada akun, tidak ada proses "ekspor data" terpisah yang diperlukan: seluruh data kamu sudah ada di perangkat kamu sendiri.',
            ),
          ),

          _SectionHeading('Kontak pengelola aplikasi'),
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'privasi@temankereta.id (placeholder — ganti dengan kontak resmi sebelum dirilis ke publik).',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  final _controller = TextEditingController();
  var _category = 'Masalah jadwal';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan lokal')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Laporan disimpan hanya di perangkat ini. Belum ada endpoint server untuk mengirimnya keluar.',
              ),
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(
                value: 'Masalah jadwal',
                child: Text('Masalah jadwal'),
              ),
              DropdownMenuItem(
                value: 'Detail stasiun',
                child: Text('Detail stasiun'),
              ),
              DropdownMenuItem(
                value: 'Aksesibilitas',
                child: Text('Aksesibilitas'),
              ),
              DropdownMenuItem(
                value: 'Masalah aplikasi',
                child: Text('Masalah aplikasi'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _category = value);
              }
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 10,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Ceritakan masalah',
              alignLabelWithHint: true,
              hintText: 'Contoh: urutan stasiun pada rute demo tidak sesuai…',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final description = _controller.text.trim();
              if (description.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tambahkan sedikitnya 10 karakter.'),
                  ),
                );
                return;
              }
              FocusScope.of(context).unfocus();
              await ref.read(appDatabaseProvider).saveUserReport(
                UserReportsCompanion.insert(
                  category: _category,
                  description: description,
                  createdAt: DateTime.now(),
                ),
              );
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Laporan "$_category" disimpan di perangkat.'),
                ),
              );
              _controller.clear();
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan laporan lokal'),
          ),
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(question),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[Text(answer)],
      ),
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  const _PrivacyItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
