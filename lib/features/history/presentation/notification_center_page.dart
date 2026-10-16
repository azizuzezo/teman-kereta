import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../data/providers/provider_registry.dart';
import '../domain/history_stats.dart';

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
    final now = ref.watch(clockProvider).now();

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
          loading: () => const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TkListSkeleton(count: 5),
          ),
          error: (error, stack) => TkErrorState(
            title: 'Notifikasi belum bisa dimuat',
            message: 'Data di perangkat ini tidak bisa dibuka. Coba lagi '
                'sebentar.',
            onRetry: () => ref.invalidate(notificationLogProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const AppEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Belum ada notifikasi',
                message:
                    'Pengingat perjalanan dan deteksi naik KRL tercatat di '
                    'sini.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _NotificationTile(entry: items[index], now: now),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.entry, required this.now});

  final NotificationLogEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    final warning = entry.notificationType == 'missed_destination';
    final sameDay = dateOnly(entry.sentAt) == dateOnly(now);
    final stamp = sameDay
        ? formatClock(entry.sentAt)
        : '${entry.sentAt.day} ${monthShortName(entry.sentAt.month)}';

    return TkCard(
      tone: warning ? TkCardTone.warning : TkCardTone.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: warning ? tk.surface : tk.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              _iconFor(entry.notificationType),
              size: 20,
              color: warning ? tk.warning : tk.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(entry.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  entry.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tk.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            stamp,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFeatures: AppTheme.timeFeatures,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(String type) => switch (type) {
  'ride_detected' => Icons.sensors_rounded,
  'transfer_alert' => Icons.sync_alt_rounded,
  'missed_destination' => Icons.warning_amber_rounded,
  _ => Icons.train_rounded,
};
