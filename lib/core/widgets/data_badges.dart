import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/entities/transit_models.dart';
import 'tk_components.dart';

/// Explanation of the "~" before a time (see [approxTime]).
const estimatedTimeNote = 'perkiraan, jam tidak tercantum di GAPEKA';

/// Explanation of the [FakultatifBadge].
const fakultatifNote = 'KA fakultatif: dijalankan sesuai kebutuhan';

/// [formatted] (e.g. `08:13`) with a leading `~` when the time is
/// [estimated]: interpolated because GAPEKA prints no time at that stop.
String approxTime(String formatted, {required bool estimated}) =>
    estimated ? '~$formatted' : formatted;

class DataFreshnessBadge extends StatelessWidget {
  const DataFreshnessBadge({
    required this.freshness,
    super.key,
    this.compact = false,
  });

  final DataFreshness freshness;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, icon, tone) = switch (freshness) {
      DataFreshness.realtime => (
        'Real-time',
        Icons.bolt_rounded,
        TkPillTone.success,
      ),
      DataFreshness.nearRealtime => (
        'Hampir real-time',
        Icons.schedule_rounded,
        TkPillTone.primary,
      ),
      DataFreshness.scheduled => (
        'Berdasarkan jadwal',
        Icons.event_note_rounded,
        TkPillTone.primary,
      ),
      DataFreshness.estimated => (
        'Estimasi',
        Icons.calculate_outlined,
        TkPillTone.warning,
      ),
      DataFreshness.unavailable => (
        'Tidak tersedia',
        Icons.info_outline_rounded,
        TkPillTone.neutral,
      ),
    };

    return Semantics(
      label: 'Status data: $label',
      excludeSemantics: true,
      child: TkPill(label: label, icon: icon, tone: tone, dense: compact),
    );
  }
}

class ServiceStatusBadge extends StatelessWidget {
  const ServiceStatusBadge({required this.status, super.key});

  final ServiceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, tone) = switch (status) {
      ServiceStatus.normal => (
        'Normal',
        Icons.check_circle_outline,
        TkPillTone.success,
      ),
      ServiceStatus.delayed => (
        'Terlambat',
        Icons.schedule,
        TkPillTone.warning,
      ),
      ServiceStatus.limited => (
        'Terbatas',
        Icons.remove_circle_outline,
        TkPillTone.warning,
      ),
      ServiceStatus.disrupted => (
        'Gangguan',
        Icons.error_outline,
        TkPillTone.danger,
      ),
      ServiceStatus.unavailable => (
        'Belum tersedia',
        Icons.help_outline,
        TkPillTone.neutral,
      ),
    };
    return Semantics(
      label: 'Status layanan $label',
      excludeSemantics: true,
      child: TkPill(label: label, icon: icon, tone: tone),
    );
  }
}

/// Small "Fakultatif" chip for a train with `service_id` [fakultatifServiceId]:
/// it only runs when needed. Long-press/hover shows [fakultatifNote].
class FakultatifBadge extends StatelessWidget {
  const FakultatifBadge({super.key, this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: fakultatifNote,
      child: Semantics(
        label: fakultatifNote,
        excludeSemantics: true,
        child: TkPill(
          label: 'Fakultatif',
          icon: Icons.event_busy_outlined,
          tone: TkPillTone.warning,
          dense: compact,
        ),
      ),
    );
  }
}

/// One-line legend under a list of times: what "~" means and, when
/// [showFakultatif], what the "Fakultatif" chip means. Shows nothing when
/// neither applies, so it can be placed unconditionally.
class TimetableNotes extends StatelessWidget {
  const TimetableNotes({
    required this.showEstimated,
    super.key,
    this.showFakultatif = false,
    this.padding = EdgeInsets.zero,
  });

  final bool showEstimated;
  final bool showFakultatif;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (!showEstimated && !showFakultatif) return const SizedBox.shrink();
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.tk.textMuted);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showEstimated) Text('~ = $estimatedTimeNote', style: style),
          if (showFakultatif) Text(fakultatifNote, style: style),
        ],
      ),
    );
  }
}
