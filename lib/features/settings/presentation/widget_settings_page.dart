import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/widget_sync.dart';
import 'settings_controller.dart';

class WidgetSettingsPage extends ConsumerWidget {
  const WidgetSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeStationId = ref.watch(settingsControllerProvider).homeStationId;

    return Scaffold(
      appBar: AppBar(title: const Text('Widget layar utama')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            const _WidgetInfoCard(
              icon: Icons.train_rounded,
              title: 'Kereta berikutnya (2×2)',
              description:
                  'Menampilkan keberangkatan terdekat dari stasiun favoritmu, status keterlambatan, dan tombol muat ulang data tersimpan.',
            ),
            const SizedBox(height: 10),
            const _WidgetInfoCard(
              icon: Icons.route_rounded,
              title: 'Rute harian (4×2)',
              description:
                  'Menampilkan rute favorit, tiga jadwal berikutnya, dan status jalur. Muncul setelah kamu menandai rute favorit.',
            ),
            const SizedBox(height: 10),
            const _WidgetInfoCard(
              icon: Icons.directions_transit_rounded,
              title: 'Perjalanan aktif',
              description:
                  'Menampilkan stasiun sekarang, stasiun berikutnya, dan progres saat perjalanan aktif berjalan.',
            ),
            const SizedBox(height: 10),
            const _WidgetInfoCard(
              icon: Icons.rule_rounded,
              title: 'Status jalur',
              description:
                  'Menampilkan status beberapa jalur commuter line: normal, terlambat, atau gangguan.',
            ),
            const SizedBox(height: 20),
            const Text(
              'Widget tidak pernah mengambil data sendiri. Tekan muat ulang '
              'di bawah untuk menyalin data terbaru yang sudah dimuat aplikasi, '
              'lalu tambahkan widget dari layar utama Android seperti biasa.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: homeStationId == null
                  ? null
                  : () async {
                      await syncAllHomeScreenWidgets(ref, homeStationId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Widget dimuat ulang dengan data terbaru.'),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Muat ulang semua widget'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetInfoCard extends StatelessWidget {
  const _WidgetInfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
      ),
    );
  }
}
