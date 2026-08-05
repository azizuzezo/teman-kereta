import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/entities/transit_models.dart';

class DemoDataBanner extends StatelessWidget {
  const DemoDataBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Data Demo, bukan informasi operasional',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 7 : 10,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.elevatedDark
              : AppColors.softBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: <Widget>[
            const Icon(Icons.science_outlined, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                compact
                    ? 'Data Demo'
                    : 'Data Demo • Bukan informasi operasional',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final (label, icon, color) = switch (freshness) {
      DataFreshness.realtime => (
        'Real-time',
        Icons.bolt_rounded,
        AppColors.success,
      ),
      DataFreshness.nearRealtime => (
        'Hampir real-time',
        Icons.schedule_rounded,
        AppColors.blue,
      ),
      DataFreshness.estimated => (
        'Estimasi',
        Icons.calculate_outlined,
        AppColors.warning,
      ),
      DataFreshness.unavailable => (
        'Tidak tersedia',
        Icons.info_outline_rounded,
        AppColors.textSecondary,
      ),
    };

    return Semantics(
      label: 'Status data: $label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceStatusBadge extends StatelessWidget {
  const ServiceStatusBadge({required this.status, super.key});

  final ServiceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      ServiceStatus.normal => (
        'Normal',
        Icons.check_circle_outline,
        AppColors.success,
      ),
      ServiceStatus.delayed => (
        'Terlambat',
        Icons.schedule,
        AppColors.warning,
      ),
      ServiceStatus.limited => (
        'Terbatas',
        Icons.remove_circle_outline,
        AppColors.warning,
      ),
      ServiceStatus.disrupted => (
        'Gangguan',
        Icons.error_outline,
        AppColors.error,
      ),
      ServiceStatus.unavailable => (
        'Belum tersedia',
        Icons.help_outline,
        AppColors.textSecondary,
      ),
    };
    return Semantics(
      label: 'Status layanan $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
