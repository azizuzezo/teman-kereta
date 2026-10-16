import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/krl_fare.dart';
import '../../../domain/usecases/trip_recap.dart';
import '../domain/history_stats.dart';
import 'share/share_cards.dart';
import 'share/share_data.dart';
import 'share/share_preview_sheet.dart';
import 'trip_history_page.dart';
import 'weekday_habit_chart.dart';

/// Period the recap page is showing. Lives in a provider so it survives
/// rebuilds while the history stream emits.
class RecapPeriodController extends Notifier<RecapPeriod> {
  @override
  RecapPeriod build() => RecapPeriod.month;

  // ignore: use_setters_to_change_properties
  void select(RecapPeriod period) => state = period;
}

final recapPeriodProvider =
    NotifierProvider<RecapPeriodController, RecapPeriod>(
      RecapPeriodController.new,
    );

/// Recap over the completed trips inside the selected period. Rebuilds
/// whenever the history stream, the station list the distance/fare figures
/// are derived from, or the period changes.
final tripRecapProvider = Provider<AsyncValue<TripRecap>>((Ref ref) {
  final history = ref.watch(tripHistoryProvider);
  final period = ref.watch(recapPeriodProvider);
  final now = ref.watch(clockProvider).now();
  // Stations only refine distance and fare; a recap of counts and times is
  // still worth showing while they load or if they fail entirely.
  final stations = ref.watch(stationListProvider).value ?? const <Station>[];
  return history.whenData((trips) {
    final byId = <String, Station>{
      for (final station in demoStations) station.id: station,
      for (final station in stations) station.id: station,
    };
    return TripRecap.from(tripsInPeriod(trips, period, now), byId);
  });
});

/// Rekap perjalanan: a period switcher, headline numbers computed from the
/// local trip log, habits and a weekday chart. Nothing here is estimated: a
/// period without trips says so instead of showing zeros dressed as stats.
class TripRecapPage extends ConsumerWidget {
  const TripRecapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(tripHistoryProvider);
    final recap = ref.watch(tripRecapProvider);
    final period = ref.watch(recapPeriodProvider);
    final now = ref.watch(clockProvider).now();
    final data = recap.value;
    final canShare = data != null && !data.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap perjalanan'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Bagikan rekap',
            onPressed: canShare
                ? () => showSharePreviewSheet(
                    context,
                    RecapShareSpec(RecapShareData.fromRecap(data, period, now)),
                  )
                : null,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: recap.when(
          loading: () => const _RecapSkeleton(),
          error: (error, stack) => TkErrorState(
            title: 'Rekap belum bisa dimuat',
            message:
                'Data perjalanan di perangkat ini tidak bisa dibuka. '
                'Coba lagi sebentar.',
            onRetry: () => ref.invalidate(tripHistoryProvider),
          ),
          data: (value) {
            if (history.value?.isEmpty ?? false) {
              return const AppEmptyState(
                icon: Icons.insights_outlined,
                title: 'Belum ada yang bisa direkap',
                message:
                    'Selesaikan satu perjalanan dulu. Rekapnya muncul di '
                    'sini, dihitung dari riwayat di perangkat ini.',
              );
            }
            return _RecapBody(
              recap: value,
              period: period,
              now: now,
              onPeriod: (next) =>
                  ref.read(recapPeriodProvider.notifier).select(next),
            );
          },
        ),
      ),
    );
  }
}

class _RecapSkeleton extends StatelessWidget {
  const _RecapSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TkSkeleton(height: 48, radius: 14),
          SizedBox(height: 16),
          TkSkeleton(height: 168, radius: 20),
          SizedBox(height: 12),
          TkSkeleton(height: 120, radius: 20),
        ],
      ),
    );
  }
}

class _RecapBody extends StatelessWidget {
  const _RecapBody({
    required this.recap,
    required this.period,
    required this.now,
    required this.onPeriod,
  });

  final TripRecap recap;
  final RecapPeriod period;
  final DateTime now;
  final ValueChanged<RecapPeriod> onPeriod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        SegmentedButton<RecapPeriod>(
          style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48)),
          showSelectedIcon: false,
          segments: <ButtonSegment<RecapPeriod>>[
            for (final value in RecapPeriod.values)
              ButtonSegment<RecapPeriod>(
                value: value,
                label: Text(value.label),
              ),
          ],
          selected: <RecapPeriod>{period},
          onSelectionChanged: (selection) => onPeriod(selection.first),
        ),
        const SizedBox(height: 16),
        if (recap.isEmpty)
          _PeriodEmpty(period: period)
        else ...<Widget>[
          _HeroCard(recap: recap, period: period, now: now),
          const SizedBox(height: 12),
          if (recap.measuredTripCount > 0) ...<Widget>[
            _SpendCard(recap: recap),
            const SizedBox(height: 12),
          ],
          const TkSectionLabel('Kebiasaan'),
          TkRowGroup(
            children: <Widget>[
              if (recap.topRoute != null)
                TkRow(
                  icon: Icons.route_rounded,
                  title: recap.topRoute!.label,
                  subtitle: 'Rute tersering, ${recap.topRoute!.count}x',
                ),
              if (recap.topStation != null)
                TkRow(
                  icon: Icons.location_on_rounded,
                  title: recap.topStation!.label,
                  subtitle: 'Stasiun tersering, ${recap.topStation!.count}x',
                ),
              if (recap.longestTrip != null)
                TkRow(
                  icon: Icons.timelapse_rounded,
                  title:
                      '${recap.longestTrip!.originName} → '
                      '${recap.longestTrip!.destinationName}',
                  subtitle:
                      'Perjalanan terlama, ${formatDuration(recap.longestTrip!.arrivedAt.difference(recap.longestTrip!.departedAt))}',
                ),
              if (recap.firstTripAt != null)
                TkRow(
                  icon: Icons.flag_rounded,
                  title: formatShortDate(recap.firstTripAt!),
                  subtitle: 'Perjalanan pertama',
                ),
            ],
          ),
          const SizedBox(height: 12),
          const TkSectionLabel('Hari naik kereta'),
          TkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (weekdaySummary(recap.tripsByWeekday) case final summary?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(summary, style: theme.textTheme.titleSmall),
                  ),
                WeekdayHabitChart(counts: recap.tripsByWeekday),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Builder(
            builder: (context) => FilledButton.icon(
              onPressed: () => showSharePreviewSheet(
                context,
                RecapShareSpec(RecapShareData.fromRecap(recap, period, now)),
              ),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Bagikan rekap'),
            ),
          ),
        ],
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

class _PeriodEmpty extends StatelessWidget {
  const _PeriodEmpty({required this.period});

  final RecapPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TkCard(
      tone: TkCardTone.alt,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Belum ada perjalanan ${period.phrase}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih periode yang lebih panjang untuk melihat perjalanan '
            'sebelumnya.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.tk.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The one focal point: how many trips in the period, then time on board and
/// active days underneath.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.recap,
    required this.period,
    required this.now,
  });

  final TripRecap recap;
  final RecapPeriod period;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    final range = periodRangeLabel(period, now, recap.firstTripAt);
    final onPrimary = tk.onPrimary;
    final softOnPrimary = onPrimary.withValues(alpha: 0.82);

    return Semantics(
      container: true,
      label:
          '${recap.tripCount} perjalanan ${period.phrase}, '
          '${formatDuration(recap.totalRideTime)} di kereta, '
          '${recap.activeDayCount} hari aktif',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tk.primary,
            borderRadius: BorderRadius.circular(TkRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                range == null
                    ? 'Perjalanan ${period.phrase}'
                    : 'Perjalanan ${period.phrase}, $range',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: softOnPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      '${recap.tripCount}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.displayLarge?.copyWith(
                        color: onPrimary,
                        fontSize: 56,
                        height: 1.05,
                        fontFeatures: AppTheme.timeFeatures,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'perjalanan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: softOnPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _HeroStat(
                      label: 'Di kereta',
                      value: formatDuration(recap.totalRideTime),
                    ),
                  ),
                  Expanded(
                    child: _HeroStat(
                      label: 'Hari aktif',
                      value: '${recap.activeDayCount}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: tk.onPrimary.withValues(alpha: 0.82),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: tk.onPrimary,
            fontFeatures: AppTheme.timeFeatures,
          ),
        ),
      ],
    );
  }
}

class _SpendCard extends StatelessWidget {
  const _SpendCard({required this.recap});

  final TripRecap recap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  label: 'Tarif terhitung',
                  value: formatRupiah(recap.totalFareRupiah),
                ),
              ),
            ],
          ),
          if (recap.hasUnmeasuredTrips) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Dihitung dari ${recap.measuredTripCount} dari '
              '${recap.tripCount} perjalanan. Sisanya belum punya data jalur '
              'untuk diukur, jadi tidak ikut dijumlahkan.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
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
          style: theme.textTheme.titleLarge?.copyWith(
            fontFeatures: AppTheme.timeFeatures,
          ),
        ),
      ],
    );
  }
}
