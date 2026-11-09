import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config/app_environment.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/tk_components.dart';

/// How late trains are running at one station in one direction, measured by
/// riders' phones (GPS arrival vs the official timetable), last 45 minutes.
class CrowdDelay {
  const CrowdDelay({
    required this.towardCode,
    required this.towardName,
    required this.medianDelaySeconds,
    required this.reporters,
    required this.lastPassedAt,
  });

  factory CrowdDelay.fromRow(Map<String, dynamic> row) => CrowdDelay(
    towardCode: row['toward_station_code'] as String,
    towardName:
        (row['toward_station_name'] as String?) ??
        row['toward_station_code'] as String,
    medianDelaySeconds: (row['median_delay_seconds'] as num?)?.toInt() ?? 0,
    reporters: (row['reporters'] as num?)?.toInt() ?? 0,
    lastPassedAt: DateTime.parse(row['last_passed_at'] as String).toLocal(),
  );

  final String towardCode;
  final String towardName;
  final int medianDelaySeconds;
  final int reporters;
  final DateTime lastPassedAt;

  int get delayMinutes => (medianDelaySeconds / 60).round();
}

/// "Tepat waktu", "Telat ±4 mnt".
String crowdDelayLabel(int delaySeconds) {
  final minutes = (delaySeconds / 60).round();
  if (minutes <= 1) return 'Tepat waktu';
  return 'Telat ±$minutes mnt';
}

/// Rider-measured delays at a station (by station code). Empty when Supabase
/// is off or nothing was reported recently.
final crowdDelaysProvider = FutureProvider.autoDispose
    .family<List<CrowdDelay>, String>((ref, stationCode) async {
      if (!AppEnvironment.supabaseEnabled) return const <CrowdDelay>[];
      try {
        final rows = await Supabase.instance.client.rpc<List<dynamic>>(
          'get_crowd_delays',
          params: <String, Object?>{'p_station_code': stationCode},
        );
        return rows
            .cast<Map<String, dynamic>>()
            .map(CrowdDelay.fromRow)
            .toList(growable: false);
      } on Object {
        // Function not deployed yet, or offline: show nothing rather than an
        // error for an optional extra.
        return const <CrowdDelay>[];
      }
    });

/// "Ketepatan jadwal dari penumpang" for one station. Shows nothing at all
/// when nobody has reported, unless [showEmpty] (then a one-line explainer).
class CrowdDelayCard extends ConsumerWidget {
  const CrowdDelayCard({
    required this.stationCode,
    this.towardCode,
    this.showEmpty = true,
    super.key,
  });

  final String stationCode;

  /// Only this direction (next station code), when given.
  final String? towardCode;
  final bool showEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final all =
        ref.watch(crowdDelaysProvider(stationCode)).asData?.value ??
        const <CrowdDelay>[];
    final delays = towardCode == null
        ? all
        : all.where((d) => d.towardCode == towardCode).toList(growable: false);
    if (delays.isEmpty && !showEmpty) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    return TkCard(
      tone: TkCardTone.alt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.groups_2_outlined, size: 20, color: tk.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ketepatan jadwal dari penumpang',
                  style: textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (delays.isEmpty)
            Text(
              'Belum ada laporan 45 menit terakhir. Laporan datang dari GPS '
              'penumpang yang sedang naik kereta dan menyalakan Deteksi '
              'Otomatis Naik KRL.',
              style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
            )
          else
            for (final d in delays)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Arah ${d.towardName}',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    TkPill(
                      label: crowdDelayLabel(d.medianDelaySeconds),
                      tone: d.delayMinutes <= 1
                          ? TkPillTone.success
                          : d.delayMinutes <= 5
                          ? TkPillTone.warning
                          : TkPillTone.danger,
                      dense: true,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${d.reporters} HP · '
                      '${now.difference(d.lastPassedAt).inMinutes} mnt lalu',
                      style: textTheme.labelSmall?.copyWith(
                        color: tk.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
