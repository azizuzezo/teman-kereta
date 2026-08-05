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
      appBar: AppBar(title: const Text('Privasi lokal')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          const Icon(Icons.shield_outlined, size: 54),
          const SizedBox(height: 18),
          Text(
            'Data tetap di perangkat pada tahap ini',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Teman Kereta berjalan dengan provider demo lokal. Sinkronisasi cloud, analitik jarak jauh, Firebase, dan deployment tidak diaktifkan.',
          ),
          const SizedBox(height: 24),
          const _PrivacyItem(
            icon: Icons.location_on_outlined,
            title: 'Lokasi',
            description:
                'Diminta bertahap. Pelacakan aktif hanya ketika perjalanan dimulai oleh pengguna.',
          ),
          const _PrivacyItem(
            icon: Icons.notifications_none_rounded,
            title: 'Notifikasi',
            description:
                'Dikirim oleh perangkat untuk simulasi peringatan stasiun; tidak memakai push server.',
          ),
          const _PrivacyItem(
            icon: Icons.storage_outlined,
            title: 'Penyimpanan',
            description:
                'Preferensi, favorit, cache, dan snapshot perjalanan disimpan secara lokal.',
          ),
          const _PrivacyItem(
            icon: Icons.cloud_off_outlined,
            title: 'Cloud',
            description:
                'Supabase lokal bersifat opsional dan tidak terhubung ke proyek remote.',
          ),
        ],
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
