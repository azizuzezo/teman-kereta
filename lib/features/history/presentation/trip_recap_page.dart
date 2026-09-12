import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/geo.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/krl_fare.dart';
import '../../../domain/usecases/trip_recap.dart';
import 'trip_history_page.dart';

/// Recap over everything in the local completed-trip log. Rebuilds whenever
/// either input changes — the history stream, or the station list the
/// distance/fare figures are derived from.
final tripRecapProvider = Provider<AsyncValue<TripRecap>>((Ref ref) {
  final history = ref.watch(tripHistoryProvider);
  // Stations only refine distance and fare; a recap of counts and times is
  // still worth showing while they load or if they fail entirely.
  final stations = ref.watch(stationListProvider).value ?? const <Station>[];
  return history.whenData((trips) {
    final byId = <String, Station>{
      for (final station in demoStations) station.id: station,
      for (final station in stations) station.id: station,
    };
    return TripRecap.from(trips, byId);
  });
});

class TripRecapPage extends ConsumerWidget {
  const TripRecapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recap = ref.watch(tripRecapProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rekap perjalanan')),
      body: SafeArea(
        child: recap.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const AppEmptyState(
            icon: Icons.insights_outlined,
            title: 'Rekap tidak dapat dimuat',
            message: 'Basis data lokal tidak dapat diakses saat ini.',
          ),
          data: (data) => data.isEmpty
              ? const AppEmptyState(
                  icon: Icons.insights_outlined,
                  title: 'Belum ada yang bisa direkap',
                  message:
                      'Selesaikan perjalanan dulu, rekapnya akan muncul di sini.',
                )
              : _RecapBody(recap: data),
        ),
      ),
    );
  }
}

class _RecapBody extends StatelessWidget {
  const _RecapBody({required this.recap});

  final TripRecap recap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMMM y', 'id_ID');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        _HeadlineCard(recap: recap),
        const SizedBox(height: 14),
        if (recap.measuredTripCount > 0) ...<Widget>[
          _SpendCard(recap: recap),
          const SizedBox(height: 14),
        ],
        Text('Kebiasaan kamu', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: <Widget>[
              if (recap.topRoute != null)
                _RecapTile(
                  icon: Icons.route_rounded,
                  title: 'Rute tersering',
                  value: recap.topRoute!.label,
                  detail: '${recap.topRoute!.count}x perjalanan',
                ),
              if (recap.topStation != null) ...<Widget>[
                const Divider(height: 1),
                _RecapTile(
                  icon: Icons.location_on_rounded,
                  title: 'Stasiun tersering',
                  value: recap.topStation!.label,
                  detail: '${recap.topStation!.count}x disinggahi',
                ),
              ],
              const Divider(height: 1),
              _RecapTile(
                icon: Icons.calendar_month_rounded,
                title: 'Hari paling sering naik',
                value: _busiestWeekdayLabel(recap.tripsByWeekday),
                detail: _weekdaySummary(recap.tripsByWeekday),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _WeekdayChart(counts: recap.tripsByWeekday),
              ),
              if (recap.longestTrip != null) ...<Widget>[
                const Divider(height: 1),
                _RecapTile(
                  icon: Icons.timelapse_rounded,
                  title: 'Perjalanan terlama',
                  value:
                      '${recap.longestTrip!.originName} → ${recap.longestTrip!.destinationName}',
                  detail: formatDuration(
                    recap.longestTrip!.arrivedAt.difference(
                      recap.longestTrip!.departedAt,
                    ),
                  ),
                ),
              ],
              if (recap.firstTripAt != null) ...<Widget>[
                const Divider(height: 1),
                _RecapTile(
                  icon: Icons.flag_rounded,
                  title: 'Perjalanan pertama',
                  value: dateFormat.format(recap.firstTripAt!),
                  detail: '${recap.activeDayCount} hari dengan perjalanan',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Rekap dihitung dari riwayat di perangkat ini saja. Menghapus '
          'riwayat juga mengosongkan rekap.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.recap});

  final TripRecap recap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Total perjalanan', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              '${recap.tripCount}x',
              style: theme.textTheme.displayLarge?.copyWith(
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Kamu menghabiskan ${formatDuration(recap.totalRideTime)} '
              'di dalam kereta.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendCard extends StatelessWidget {
  const _SpendCard({required this.recap});

  final TripRecap recap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _BigStat(
                    label: 'Jarak ditempuh',
                    value: formatDistanceMeters(
                      recap.totalDistanceMeters.toDouble(),
                    ),
                  ),
                ),
                Expanded(
                  child: _BigStat(
                    label: 'Tarif terbayar',
                    value: formatRupiah(recap.totalFareRupiah),
                  ),
                ),
              ],
            ),
            if (recap.hasUnmeasuredTrips) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Dihitung dari ${recap.measuredTripCount} dari '
                '${recap.tripCount} perjalanan — sisanya belum punya data '
                'jalur untuk diukur, jadi tidak ikut dijumlahkan.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _RecapTile extends StatelessWidget {
  const _RecapTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: theme.textTheme.bodySmall),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: theme.textTheme.titleMedium),
          Text(detail, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _WeekdayChart extends StatelessWidget {
  const _WeekdayChart({required this.counts});

  final Map<int, int> counts;

  static const _order = <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  static const _shortNames = <int, String>{
    DateTime.monday: 'Sen',
    DateTime.tuesday: 'Sel',
    DateTime.wednesday: 'Rab',
    DateTime.thursday: 'Kam',
    DateTime.friday: 'Jum',
    DateTime.saturday: 'Sab',
    DateTime.sunday: 'Min',
  };

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 132,
      child: Row(
        children: <Widget>[
          for (final day in _order)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _WeekdayBar(
                  count: counts[day] ?? 0,
                  maxCount: maxCount,
                  label: _shortNames[day]!,
                  isBusiest: maxCount > 0 && (counts[day] ?? 0) == maxCount,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekdayBar extends StatelessWidget {
  const _WeekdayBar({
    required this.count,
    required this.maxCount,
    required this.label,
    required this.isBusiest,
  });

  final int count;
  final int maxCount;
  final String label;
  final bool isBusiest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxCount == 0 ? 0.0 : count / maxCount;
    final barColor = isBusiest
        ? theme.colorScheme.primary
        : theme.colorScheme.primary.withValues(alpha: 0.25);
    return Column(
      children: <Widget>[
        Text(
          count == 0 ? '' : '$count',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: isBusiest ? theme.colorScheme.primary : null,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fraction,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

const _weekdayNames = <int, String>{
  DateTime.monday: 'Senin',
  DateTime.tuesday: 'Selasa',
  DateTime.wednesday: 'Rabu',
  DateTime.thursday: 'Kamis',
  DateTime.friday: 'Jumat',
  DateTime.saturday: 'Sabtu',
  DateTime.sunday: 'Minggu',
};

String _busiestWeekdayLabel(Map<int, int> counts) {
  if (counts.isEmpty) {
    return '-';
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      // Ties resolve to the earlier weekday so the label is stable.
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return _weekdayNames[entries.first.key] ?? '-';
}

String _weekdaySummary(Map<int, int> counts) {
  if (counts.isEmpty) {
    return '-';
  }
  final total = counts.values.reduce((a, b) => a + b);
  final busiest = counts.values.reduce((a, b) => a > b ? a : b);
  final percent = ((busiest / total) * 100).round();
  return '$busiest dari $total perjalanan ($percent%)';
}
