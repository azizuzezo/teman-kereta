import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../data/providers/provider_registry.dart';
import '../domain/history_stats.dart';
import 'share/share_cards.dart';
import 'share/share_data.dart';
import 'share/share_preview_sheet.dart';

final tripHistoryProvider = StreamProvider<List<CompletedTrip>>((Ref ref) {
  return ref.watch(appDatabaseProvider).watchCompletedTrips();
});

/// Riwayat perjalanan: completed trips from the local log, grouped by day,
/// newest first. Tapping a row opens its detail with a share action.
class TripHistoryPage extends ConsumerWidget {
  const TripHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(tripHistoryProvider);
    final hasTrips = history.value?.isNotEmpty ?? false;

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
            onPressed: hasTrips ? () => _confirmClear(context, ref) : null,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: history.when(
          loading: () => const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TkListSkeleton(count: 5),
          ),
          error: (error, stack) => TkErrorState(
            title: 'Riwayat belum bisa dimuat',
            message:
                'Data perjalanan di perangkat ini tidak bisa dibuka. '
                'Coba lagi sebentar.',
            onRetry: () => ref.invalidate(tripHistoryProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return AppEmptyState(
                icon: Icons.history_rounded,
                title: 'Belum ada perjalanan selesai',
                message:
                    'Perjalanan yang kamu selesaikan tercatat di sini, '
                    'lengkap dengan rekapnya.',
                action: FilledButton(
                  onPressed: () => context.go('/schedule/search'),
                  child: const Text('Cari kereta'),
                ),
              );
            }
            return _HistoryList(trips: items);
          },
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final tk = context.tk;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus semua riwayat?'),
        content: const Text(
          'Semua perjalanan dan rekapnya ikut terhapus dari perangkat ini. '
          'Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: tk.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus riwayat'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(appDatabaseProvider).clearCompletedTrips();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Riwayat dihapus.')));
      }
    }
  }
}

sealed class _Entry {
  const _Entry();
}

class _HeaderEntry extends _Entry {
  const _HeaderEntry(this.label, this.count);

  final String label;
  final int count;
}

class _TripEntry extends _Entry {
  const _TripEntry(this.trip);

  final CompletedTrip trip;
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.trips});

  final List<CompletedTrip> trips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).now();
    final entries = <_Entry>[
      for (final group in groupTripsByDay(trips)) ...<_Entry>[
        _HeaderEntry(dayGroupLabel(group.day, now), group.trips.length),
        for (final trip in group.trips) _TripEntry(trip),
      ],
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return switch (entry) {
          _HeaderEntry() => Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
            child: Semantics(
              header: true,
              child: TkSectionLabel(
                entry.label,
                trailing: Text(
                  '${entry.count} perjalanan',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          _TripEntry() => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TripHistoryCard(trip: entry.trip),
          ),
        };
      },
    );
  }
}

class _TripHistoryCard extends StatelessWidget {
  const _TripHistoryCard({required this.trip});

  final CompletedTrip trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = tripDuration(trip);
    final semantic =
        '${trip.originName} ke ${trip.destinationName}, '
        '${formatClock(trip.departedAt)} sampai ${formatClock(trip.arrivedAt)}'
        '${duration == null ? '' : ', ${formatDuration(duration)}'}';

    return TkCard(
      semanticLabel: semantic,
      onTap: () => _showTripDetail(context, trip),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: _RouteSummary(
                origin: trip.originName,
                destination: trip.destinationName,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formatClock(trip.departedAt),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFeatures: AppTheme.timeFeatures,
                  ),
                ),
                if (duration != null)
                  Text(
                    formatDuration(duration),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: AppTheme.timeFeatures,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Origin and destination joined by the route motif. The dot column grows
/// with the text scale so labels stay level with their dots.
class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.origin, required this.destination});

  final String origin;
  final String destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height = 58 * (scale < 1 ? 1.0 : scale);
    return Row(
      children: <Widget>[
        TkRouteDots(count: 2, filled: 2, height: height),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  origin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showTripDetail(BuildContext context, CompletedTrip trip) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _TripDetailSheet(
      trip: trip,
      onShare: () {
        Navigator.of(sheetContext).pop();
        if (context.mounted) {
          unawaited(
            showSharePreviewSheet(
              context,
              TripShareSpec(TripShareData.fromCompleted(trip)),
            ),
          );
        }
      },
    ),
  );
}

class _TripDetailSheet extends StatelessWidget {
  const _TripDetailSheet({required this.trip, required this.onShare});

  final CompletedTrip trip;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = tripDuration(trip);
    final line = trip.lineName?.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Detail perjalanan',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (trip.isDemo)
                const TkPill(label: 'Data demo', tone: TkPillTone.warning),
            ],
          ),
          const SizedBox(height: 16),
          TkCard(
            tone: TkCardTone.alt,
            child: _RouteSummary(
              origin: trip.originName,
              destination: trip.destinationName,
            ),
          ),
          const SizedBox(height: 8),
          _DetailLine(
            label: 'Tanggal',
            value: formatShortDate(trip.departedAt),
          ),
          _DetailLine(
            label: 'Berangkat',
            value: formatClock(trip.departedAt),
            tabular: true,
          ),
          _DetailLine(
            label: 'Tiba',
            value: formatClock(trip.arrivedAt),
            tabular: true,
          ),
          if (duration != null)
            _DetailLine(label: 'Durasi', value: formatDuration(duration)),
          if (line != null && line.isNotEmpty)
            _DetailLine(label: 'Jalur', value: line),
          const SizedBox(height: 4),
          Text(
            'Jam mengikuti jadwal perjalanan yang kamu pilih.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Bagikan'),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.tabular = false,
  });

  final String label;
  final String value;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.tk.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: tabular ? AppTheme.timeFeatures : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
