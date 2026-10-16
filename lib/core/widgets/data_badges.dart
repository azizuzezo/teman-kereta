import 'package:flutter/material.dart';

import '../../domain/entities/transit_models.dart';
import 'tk_components.dart';

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
