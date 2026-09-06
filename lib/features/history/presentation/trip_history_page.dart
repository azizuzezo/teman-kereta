import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/empty_state.dart';

final tripHistoryProvider = StreamProvider<List<CompletedTrip>>((Ref ref) {
  return ref.watch(appDatabaseProvider).watchCompletedTrips();
});

class TripHistoryPage extends ConsumerWidget {
  const TripHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(tripHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat perjalanan'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Rekap perjalanan',
            onPressed: () => context.push('/history/recap'),
            icon: const Icon(Icons.insights_rounded),
          ),
          IconButton(
            tooltip: 'Hapus semua riwayat',
            onPressed: () => _confirmClear(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const AppEmptyState(
            icon: Icons.history_toggle_off_rounded,
            title: 'Riwayat tidak dapat dimuat',
            message: 'Basis data lokal tidak dapat diakses saat ini.',
          ),
          data: (items) {
            if (items.isEmpty) {
              return const AppEmptyState(
                icon: Icons.history_rounded,
                title: 'Belum ada perjalanan selesai',
                message:
                    'Perjalanan yang kamu selesaikan akan muncul di sini.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _TripHistoryCard(trip: items[index]),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus semua riwayat?'),
        content: const Text(
          'Tindakan ini tidak dapat dibatalkan. Riwayat hanya tersimpan di perangkat ini.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(appDatabaseProvider).clearCompletedTrips();
    }
  }
}

class _TripHistoryCard extends StatelessWidget {
  const _TripHistoryCard({required this.trip});

  final CompletedTrip trip;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat.Hm('id_ID');
    final dateFormatter = DateFormat('d MMM y', 'id_ID');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${trip.originName} → ${trip.destinationName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${formatter.format(trip.departedAt)} – ${formatter.format(trip.arrivedAt)} • '
              '${trip.lineName ?? 'Commuter Line'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Selesai ${dateFormatter.format(trip.completedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
