import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gtfs_import_controller.dart';

class GtfsImportPage extends ConsumerWidget {
  const GtfsImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(gtfsImportControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Impor jadwal GTFS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            const Text(
              'Impor berkas GTFS Schedule (statis) — stops.txt, routes.txt, '
              'trips.txt, stop_times.txt, dan calendar.txt/calendar_dates.txt '
              'dikemas dalam satu file .zip — untuk mengganti jadwal Data Demo '
              'dengan jadwal nyata saat mode provider diatur ke "gtfs".',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: switch (status) {
                  AsyncData<GtfsImportStatus>(value: final value) =>
                    _StatusView(status: value),
                  AsyncError<GtfsImportStatus>(:final error) => Text(
                    'Impor gagal: $error',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  _ => const Row(
                    children: <Widget>[
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Memproses berkas GTFS…'),
                    ],
                  ),
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: status.isLoading
                  ? null
                  : () => ref
                        .read(gtfsImportControllerProvider.notifier)
                        .pickAndImportZip(),
              icon: const Icon(Icons.file_open_rounded),
              label: const Text('Pilih file GTFS (.zip)'),
            ),
            const SizedBox(height: 12),
            Text(
              'Impor menggantikan seluruh jadwal GTFS statis yang tersimpan '
              'sebelumnya. Selama belum ada jadwal yang diimpor, mode "gtfs" '
              'tetap menampilkan Data Demo untuk jadwal dan stasiun.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.status});

  final GtfsImportStatus status;

  @override
  Widget build(BuildContext context) {
    final summary = status.lastImportSummary;
    if (!status.hasImportedData) {
      return const Text('Belum ada jadwal GTFS statis yang diimpor.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${status.stopCount} stasiun GTFS statis tersimpan.',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (summary != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Impor terakhir: ${summary.routeCount} jalur, ${summary.tripCount} '
            'trip, ${summary.stopTimeCount} jadwal perhentian, '
            '${summary.serviceCount} kalender layanan.',
          ),
        ],
      ],
    );
  }
}
