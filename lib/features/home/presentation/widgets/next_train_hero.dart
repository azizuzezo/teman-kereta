import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/data_badges.dart';
import '../../../../core/widgets/tk_components.dart';
import '../../../../domain/entities/transit_models.dart';
import '../../../../domain/usecases/travel_estimate.dart';
import '../../domain/next_train_logic.dart';

/// The one focal point of Home: the station the rider is nearest to (or, when
/// there is no GPS fix, their home station), the walk/ride estimate to it and
/// the next train leaving from it.
class NextTrainHero extends StatelessWidget {
  const NextTrainHero({
    required this.choice,
    required this.stationName,
    required this.departures,
    required this.now,
    required this.onOpenStation,
    required this.onDirections,
    required this.onSeeAllNearby,
    required this.onRetry,
    super.key,
    this.vehicle,
    this.progress,
  });

  final BoardChoice choice;
  final String stationName;
  final AsyncValue<List<Departure>> departures;
  final DateTime now;
  final VehiclePosition? vehicle;
  final TrainProgress? progress;
  final VoidCallback onOpenStation;
  final VoidCallback onDirections;
  final VoidCallback onSeeAllNearby;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final nearest = choice.nearest;
    final label = switch (choice.source) {
      BoardSource.nearest => 'Stasiun terdekat',
      BoardSource.home => 'Stasiun rumah',
      BoardSource.fallback => 'Stasiun bawaan',
    };
    final icon = switch (choice.source) {
      BoardSource.nearest => Icons.near_me_rounded,
      BoardSource.home => Icons.home_rounded,
      BoardSource.fallback => Icons.train_rounded,
    };
    final estimateLine = nearest == null
        ? null
        : formatEstimateLine(nearest.estimate);
    final contextLine = switch (choice.source) {
      BoardSource.nearest =>
        nearest!.estimate.isReliable
            ? '${formatDistance(nearest.distanceMeters)} dari kamu'
            : '${formatDistance(nearest.distanceMeters)} dari kamu, terlalu jauh untuk diperkirakan',
      BoardSource.home => 'Lokasi belum aktif, memakai stasiun rumahmu.',
      BoardSource.fallback =>
        'Nyalakan lokasi atau atur stasiun rumah di Profil.',
    };

    return TkCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: tk.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(color: tk.primary),
                ),
              ),
              if (choice.source == BoardSource.nearest)
                TextButton(
                  onPressed: onSeeAllNearby,
                  child: const Text('Lihat semua'),
                ),
            ],
          ),
          Text(
            'Stasiun $stationName',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: 2),
          Text(
            contextLine,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(color: tk.textMuted),
          ),
          if (estimateLine != null) ...<Widget>[
            const SizedBox(height: 6),
            Semantics(
              label: 'Perkiraan menuju stasiun: $estimateLine',
              excludeSemantics: true,
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.directions_walk_rounded,
                    size: 18,
                    color: tk.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      estimateLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: textTheme.bodyMedium?.copyWith(
                        fontFeatures: AppTheme.timeFeatures,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: tk.border),
          const SizedBox(height: 12),
          _Body(
            stationName: stationName,
            departures: departures,
            now: now,
            vehicle: vehicle,
            progress: progress,
            onOpenStation: onOpenStation,
            onRetry: onRetry,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenStation,
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: const Text('Lihat jadwal'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text('Arah ke stasiun'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.stationName,
    required this.departures,
    required this.now,
    required this.vehicle,
    required this.progress,
    required this.onOpenStation,
    required this.onRetry,
  });

  final String stationName;
  final AsyncValue<List<Departure>> departures;
  final DateTime now;
  final VehiclePosition? vehicle;
  final TrainProgress? progress;
  final VoidCallback onOpenStation;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return departures.when(
      loading: () => const _BodySkeleton(),
      error: (error, stack) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.cloud_off_rounded, size: 20, color: tk.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Jadwal belum bisa dimuat',
                  style: textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Periksa koneksi, lalu coba lagi.',
            style: textTheme.bodyMedium?.copyWith(color: tk.textMuted),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
      data: (items) {
        final upcoming = upcomingDepartures(items, now, limit: 3);
        if (upcoming.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Tidak ada kereta lagi', style: textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Belum ada keberangkatan berikutnya dari stasiun ini. '
                'Cek jadwal lengkap untuk besok.',
                style: textTheme.bodyMedium?.copyWith(color: tk.textMuted),
              ),
            ],
          );
        }
        final first = upcoming.first;
        final rest = upcoming.skip(1).toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Kereta berikutnya',
                    style: textTheme.labelMedium,
                  ),
                ),
                if (first.isDemo) ...<Widget>[
                  const TkPill(
                    label: 'Data demo',
                    icon: Icons.science_outlined,
                    tone: TkPillTone.warning,
                    dense: true,
                  ),
                  const SizedBox(width: 6),
                ],
                DataFreshnessBadge(freshness: first.freshness, compact: true),
              ],
            ),
            const SizedBox(height: 10),
            _FirstDeparture(
              departure: first,
              stationName: stationName,
              now: now,
            ),
            const SizedBox(height: 12),
            _LivePosition(vehicle: vehicle, progress: progress, now: now),
            if (rest.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Divider(color: tk.border),
              const SizedBox(height: 4),
              for (final d in rest) _FollowUpRow(departure: d, now: now),
            ],
          ],
        );
      },
    );
  }
}

class _FirstDeparture extends StatelessWidget {
  const _FirstDeparture({
    required this.departure,
    required this.stationName,
    required this.now,
  });

  final Departure departure;
  final String stationName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final row1 = scaler.scale(22);
    final row2 = scaler.scale(24);
    const gap = 8.0;
    final dotsHeight = row1 / 2 + gap + row2 / 2 + 10;
    final time = DateFormat.Hm('id_ID').format(departure.expectedAt);
    final countdown = countdownLabel(departure.expectedAt.difference(now));
    final platform = platformLabel(departure.platform);
    final detail = <String>[departure.lineName, ?platform].join(' · ');

    return Semantics(
      label:
          'Kereta berikutnya ke ${departure.destination}, berangkat $time, '
          '$countdown',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(top: row1 / 2 - 5),
                child: TkRouteDots(count: 2, filled: 1, height: dotsHeight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      height: row1,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          stationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: tk.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: gap),
                    SizedBox(
                      height: row2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          departure.destination,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    time,
                    maxLines: 1,
                    style: textTheme.displayLarge?.copyWith(
                      fontFeatures: AppTheme.timeFeatures,
                      color: tk.primary,
                    ),
                  ),
                  Text(
                    countdown,
                    maxLines: 1,
                    style: textTheme.labelLarge?.copyWith(
                      fontFeatures: AppTheme.timeFeatures,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Where the train being shown actually is, when a provider reports it.
/// Otherwise one honest line saying the time follows the schedule.
class _LivePosition extends StatelessWidget {
  const _LivePosition({
    required this.vehicle,
    required this.progress,
    required this.now,
  });

  final VehiclePosition? vehicle;
  final TrainProgress? progress;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final v = vehicle;
    final p = progress;
    if (v == null || p == null) {
      return Row(
        children: <Widget>[
          Icon(Icons.schedule_rounded, size: 16, color: tk.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Posisi kereta belum tersedia, waktu mengikuti jadwal.',
              style: textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    final place = switch ((p.previousName, p.nextName)) {
      (final String a, final String b) => 'antara $a dan $b',
      (null, final String b) => 'menuju $b',
      (final String a, null) => 'setelah $a',
      _ => 'di jalur',
    };
    final age = now.difference(v.recordedAt);
    final ageLabel = age.inSeconds < 60
        ? 'baru saja'
        : '${age.inMinutes} mnt lalu';
    final summary =
        'Kereta ini $place, ${formatDistance(p.distanceToBoardMeters)} dari '
        'stasiun ini. Diperbarui $ageLabel.';

    return Semantics(
      label: summary,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tk.surfaceAlt,
          borderRadius: BorderRadius.circular(TkRadius.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.train_rounded, size: 18, color: tk.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kereta ini $place',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (p.fraction != null) ...<Widget>[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: p.fraction,
                  minHeight: 6,
                  backgroundColor: tk.border,
                  color: tk.primary,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${formatDistance(p.distanceToBoardMeters)} dari stasiun ini'
              ' · diperbarui $ageLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                fontFeatures: AppTheme.timeFeatures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowUpRow extends StatelessWidget {
  const _FollowUpRow({required this.departure, required this.now});

  final Departure departure;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final time = DateFormat.Hm('id_ID').format(departure.expectedAt);
    final countdown = countdownLabel(departure.expectedAt.difference(now));
    return Semantics(
      label: 'Berikutnya ke ${departure.destination}, $time, $countdown',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 58),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  time,
                  maxLines: 1,
                  softWrap: false,
                  style: textTheme.titleMedium?.copyWith(
                    fontFeatures: AppTheme.timeFeatures,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    departure.destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                  Text(
                    countdown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      fontFeatures: AppTheme.timeFeatures,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BodySkeleton extends StatelessWidget {
  const _BodySkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Memuat jadwal',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TkSkeleton(height: 12, width: 110),
          SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(child: TkSkeleton(height: 44)),
              SizedBox(width: 16),
              TkSkeleton(height: 44, width: 96),
            ],
          ),
          SizedBox(height: 14),
          TkSkeleton(height: 14),
          SizedBox(height: 10),
          TkSkeleton(height: 14, width: 200),
        ],
      ),
    );
  }
}

/// Placeholder for the whole hero while the station list itself is loading.
class NextTrainHeroSkeleton extends StatelessWidget {
  const NextTrainHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const TkCard(
      semanticLabel: 'Memuat stasiun terdekat',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TkSkeleton(height: 14, width: 120),
          SizedBox(height: 12),
          TkSkeleton(height: 26, width: 220),
          SizedBox(height: 10),
          TkSkeleton(height: 14, width: 180),
          SizedBox(height: 22),
          _BodySkeleton(),
          SizedBox(height: 20),
          TkSkeleton(height: 52),
        ],
      ),
    );
  }
}
