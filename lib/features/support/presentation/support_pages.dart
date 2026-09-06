import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/auth_guard.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bantuan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          Text('Pertanyaan umum', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const _Faq(
            question: 'Apakah jadwal ini real-time?',
            answer:
                'Jadwal dihitung berdasarkan jadwal operasional resmi dan estimasi perjalanan. Setiap informasi diberi indikator kesegaran data.',
          ),
          const _Faq(
            question: 'Kapan lokasi latar belakang digunakan?',
            answer:
                'Hanya setelah kamu memilih Mulai perjalanan. Layanan berhenti saat perjalanan diselesaikan atau dibatalkan.',
          ),
          const _Faq(
            question: 'Apakah saya harus membuat akun?',
            answer:
                'Ya, masuk atau membuat akun diperlukan untuk menggunakan aplikasi ini — preferensi dan riwayatmu tersimpan pada akunmu.',
          ),
          const _Faq(
            question: 'Mengapa peta berbentuk skema?',
            answer:
                'Skema jalur dirancang agar ringan, mudah dibaca, dan berfungsi dengan cepat tanpa membutuhkan koneksi data tinggi.',
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
            'Privasi dan Keamanan Data',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Teman Kereta mengutamakan privasi pengguna. Halaman ini menjelaskan data apa saja yang diproses, mengapa, di mana disimpan, dan hak-hak kamu sebagai pengguna.',
          ),
          const SizedBox(height: 28),

          _SectionHeading('Data yang dikumpulkan dan alasannya'),
          const _PrivacyItem(
            icon: Icons.location_on_outlined,
            title: 'Lokasi',
            description:
                'Dipakai untuk mencari stasiun terdekat dan memandu perjalanan aktifmu secara real-time. Saat deteksi otomatis naik KRL aktif, lokasimu juga dipakai untuk mengenali kapan kamu berangkat dari stasiun. Selama perjalanan aktif berlangsung, posisimu dikirim sesekali agar penumpang lain bisa melihat posisi kereta yang sama — lihat bagian "Berbagi posisi saat naik KRL" di bawah.',
          ),
          const _PrivacyItem(
            icon: Icons.notifications_none_rounded,
            title: 'Notifikasi',
            description:
                'Dikirim dari perangkatmu sendiri untuk mengingatkan stasiun dan transit, ditambah pemberitahuan dari kami soal gangguan layanan KRL.',
          ),
          const _PrivacyItem(
            icon: Icons.schedule_outlined,
            title: 'Jadwal dan data stasiun',
            description:
                'Berasal dari data jadwal terverifikasi yang diperbarui berkala, sama untuk semua pengguna.',
          ),
          const _PrivacyItem(
            icon: Icons.account_circle_outlined,
            title: 'Akun dan profil',
            description:
                'Untuk masuk, kami menyimpan email, nama, dan username yang kamu pilih. Preferensi seperti stasiun rumah/kantor dan rute favorit tersimpan pada akunmu.',
          ),
          const _PrivacyItem(
            icon: Icons.forum_outlined,
            title: 'Forum dan fitur sosial',
            description:
                'Postingan, komentar, dan siapa yang kamu ikuti bersifat terlihat oleh pengguna lain — perlakukan seperti media sosial pada umumnya.',
          ),
          const _PrivacyItem(
            icon: Icons.flag_outlined,
            title: 'Laporan pengguna',
            description:
                'Laporan yang kamu tulis (mis. kepadatan, AC mati) tersimpan di perangkat ini dan belum dikirim ke mana pun — belum ada yang bisa melihatnya selain kamu sendiri.',
          ),
          const _PrivacyItem(
            icon: Icons.history_outlined,
            title: 'Riwayat perjalanan dan preferensi',
            description:
                'Tersimpan di perangkatmu sendiri, tidak dibagikan ke pengguna lain.',
          ),
          const _PrivacyItem(
            icon: Icons.bug_report_outlined,
            title: 'Laporan kerusakan aplikasi (crash)',
            description:
                'Fiturnya ada tapi tidak aktif secara default. Jika suatu saat diaktifkan, halaman ini akan diperbarui terlebih dahulu untuk menjelaskannya.',
          ),
          const _PrivacyItem(
            icon: Icons.block_flipped,
            title: 'Analitik dan iklan',
            description:
                'Kami tidak memasang pelacak analitik atau iklan pihak ketiga mana pun di aplikasi ini.',
          ),

          const SizedBox(height: 12),
          _SectionHeading('Berbagi posisi saat naik KRL'),
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Text(
              'Saat "Deteksi otomatis naik KRL" aktif dan kamu sedang dalam perjalanan, posisi GPS-mu dikirim sesekali agar pengguna lain di kereta yang sama bisa melihat posisi keretanya. Laporan ini disimpan sementara, dihapus otomatis paling lama 10 menit, dan digabung dengan laporan penumpang lain menjadi satu posisi rata-rata per kereta sebelum ditampilkan — tidak pernah ditampilkan sebagai posisi milikmu sendiri.',
            ),
          ),

          _SectionHeading('Penghapusan data'),
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Text(
              'Untuk menghapus akunmu beserta data yang tersimpan padanya, hubungi kami lewat kontak di bawah. Data yang hanya tersimpan di perangkat (laporan lokal) juga ikut terhapus jika kamu mencopot pemasangan aplikasi.',
            ),
          ),

          _SectionHeading('Hak kamu'),
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Text(
              'Kamu dapat mencabut izin lokasi, izin aktivitas fisik, dan izin notifikasi kapan pun lewat Pengaturan Android — aplikasi tetap bisa dipakai dengan fitur yang menyesuaikan (lihat Bantuan).',
            ),
          ),

          _SectionHeading('Kontak pengelola aplikasi'),
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('privasi@temankereta.id'),
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
              hintText: 'Contoh: urutan stasiun pada salah satu rute tidak sesuai…',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              checkAuthOrPrompt(
                context,
                featureName: 'Kirim Laporan',
                onAllowed: () async {
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
              );
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
