import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/native_trip_service.dart';
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
              widgetId: 'nextDeparture',
              icon: Icons.train_rounded,
              title: 'Kereta berikutnya (2×2)',
              description:
                  'Menampilkan keberangkatan terdekat dari stasiun favoritmu, status keterlambatan, dan tombol muat ulang data tersimpan.',
              preview: _WidgetPreview(
                background: _WidgetColors.surface,
                children: <Widget>[
                  _PreviewBadge('BELUM ADA DATA'),
                  SizedBox(height: 8),
                  Text(
                    'Pilih stasiun di aplikasi',
                    style: TextStyle(
                      color: _WidgetColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '—',
                    style: TextStyle(
                      color: _WidgetColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    'Belum ada jadwal tersimpan',
                    style: TextStyle(
                      color: _WidgetColors.secondary,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Buka aplikasi untuk mengatur',
                    style: TextStyle(
                      color: _WidgetColors.secondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _WidgetInfoCard(
              widgetId: 'dailyRoute',
              icon: Icons.route_rounded,
              title: 'Rute harian (4×2)',
              description:
                  'Menampilkan rute favorit, tiga jadwal berikutnya, dan status jalur. Muncul setelah kamu menandai rute favorit.',
              preview: _WidgetPreview(
                background: _WidgetColors.surfaceActive,
                children: <Widget>[
                  _PreviewBadge('BELUM ADA DATA'),
                  SizedBox(height: 8),
                  Text(
                    'Pilih rute favorit di aplikasi',
                    style: TextStyle(
                      color: _WidgetColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Status jalur belum tersedia',
                    style: TextStyle(
                      color: _WidgetColors.secondary,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(height: 8),
                  _PreviewDepartureRow(),
                  _PreviewDepartureRow(),
                  _PreviewDepartureRow(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _WidgetInfoCard(
              widgetId: 'activeTrip',
              icon: Icons.directions_transit_rounded,
              title: 'Perjalanan aktif',
              description:
                  'Menampilkan stasiun sekarang, stasiun berikutnya, dan progres saat perjalanan aktif berjalan.',
              preview: _WidgetPreview(
                background: _WidgetColors.surfaceActive,
                children: <Widget>[
                  _PreviewBadge('BELUM ADA DATA'),
                  SizedBox(height: 8),
                  Text(
                    'Tidak ada perjalanan aktif',
                    style: TextStyle(
                      color: _WidgetColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Mulai perjalanan dari aplikasi',
                    style: TextStyle(
                      color: _WidgetColors.secondary,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    child: LinearProgressIndicator(
                      value: 0,
                      minHeight: 5,
                      backgroundColor: Color(0x33FFFFFF),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _WidgetColors.activeAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _WidgetInfoCard(
              widgetId: 'serviceStatus',
              icon: Icons.rule_rounded,
              title: 'Status jalur',
              description:
                  'Menampilkan status beberapa jalur commuter line: normal, terlambat, atau gangguan.',
              preview: _WidgetPreview(
                background: _WidgetColors.surfaceActive,
                children: <Widget>[
                  _PreviewBadge('BELUM ADA DATA'),
                  SizedBox(height: 10),
                  Text(
                    'Buka aplikasi untuk memuat status',
                    style: TextStyle(
                      color: _WidgetColors.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
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
                            content: Text(
                              'Widget dimuat ulang dengan data terbaru.',
                            ),
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

abstract final class _WidgetColors {
  static const surface = Color(0xFF102E2A);
  static const surfaceActive = Color(0xFF18334D);
  static const primary = Color(0xFFF7FBFA);
  static const secondary = Color(0xFFBED0CC);
  static const activeAccent = Color(0xFF8CCBFF);
  static const badgeBackground = Color(0xFFFFF0B5);
  static const badgeText = Color(0xFF4D3B00);
}

class _WidgetInfoCard extends StatelessWidget {
  const _WidgetInfoCard({
    required this.widgetId,
    required this.icon,
    required this.title,
    required this.description,
    required this.preview,
  });

  final String widgetId;
  final IconData icon;
  final String title;
  final String description;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(description),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            preview,
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _requestPin(context),
                icon: const Icon(Icons.add_to_home_screen_rounded),
                label: const Text('Pasang di layar utama'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPin(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    final result = await container
        .read(nativeTripServiceProvider)
        .requestPinAppWidget(widgetId);
    if (!context.mounted) {
      return;
    }
    final message = result.supported && result.requested
        ? 'Ikuti konfirmasi dari sistem untuk menambahkan widget.'
        : 'Perangkatmu belum mendukung penambahan otomatis. Tekan lama '
              'layar utama, pilih Widget, lalu cari Teman Kereta.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({required this.background, required this.children});

  final Color background;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _WidgetColors.badgeBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _WidgetColors.badgeText,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreviewDepartureRow extends StatelessWidget {
  const _PreviewDepartureRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Text(
              '—',
              style: TextStyle(
                color: _WidgetColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          SizedBox(width: 6),
          Text(
            'Belum ada jadwal tersimpan',
            style: TextStyle(color: _WidgetColors.secondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
