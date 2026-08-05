import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/empty_state.dart';

final notificationLogProvider = StreamProvider<List<NotificationLogEntry>>((
  Ref ref,
) {
  return ref.watch(appDatabaseProvider).watchNotificationLog();
});

class NotificationCenterPage extends ConsumerWidget {
  const NotificationCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(notificationLogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pusat notifikasi'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Pengaturan notifikasi',
            onPressed: () => context.push('/settings/notifications'),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: log.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const AppEmptyState(
            icon: Icons.notifications_off_outlined,
            title: 'Riwayat notifikasi tidak dapat dimuat',
            message: 'Basis data lokal tidak dapat diakses saat ini.',
          ),
          data: (items) {
            if (items.isEmpty) {
              return const AppEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Belum ada notifikasi',
                message:
                    'Notifikasi perjalanan dan deteksi naik KRL akan tercatat di sini.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = items[index];
                return Card(
                  child: ListTile(
                    leading: Icon(_iconFor(entry.notificationType)),
                    title: Text(entry.title),
                    subtitle: Text(entry.body),
                    trailing: Text(
                      DateFormat.Hm('id_ID').format(entry.sentAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
    'ride_detected' => Icons.sensors_rounded,
    'transfer_alert' => Icons.sync_alt_rounded,
    'missed_destination' => Icons.warning_amber_rounded,
    _ => Icons.train_rounded,
  };
}
