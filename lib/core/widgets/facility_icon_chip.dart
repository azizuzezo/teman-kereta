import 'package:flutter/material.dart';

/// A single station facility (e.g. "Toilet", "Musala", "Wi-Fi"), shown as a
/// compact icon badge instead of a text chip — the facility name is still
/// available via [Tooltip] (long-press on touch, hover on desktop) and to
/// screen readers, it just isn't printed inline anymore.
class FacilityIconChip extends StatelessWidget {
  const FacilityIconChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(
          facilityIcon(label),
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Best-effort icon for a facility label — matched by keyword so it degrades
/// gracefully for facility strings this table hasn't seen yet.
IconData facilityIcon(String facility) {
  final f = facility.toLowerCase();
  if (f.contains('toilet')) return Icons.wc_rounded;
  if (f.contains('musala') || f.contains('mushola') || f.contains('mushala')) {
    return Icons.mosque_rounded;
  }
  if (f.contains('parkir')) return Icons.local_parking_rounded;
  if (f.contains('lift') || f.contains('elevator')) return Icons.elevator_rounded;
  if (f.contains('eskalator') || f.contains('escalator')) return Icons.escalator_rounded;
  if (f.contains('loket') || f.contains('tiket') || f.contains('ticket')) {
    return Icons.confirmation_number_outlined;
  }
  if (f.contains('charging') || f.contains('daya') || f.contains('colokan')) {
    return Icons.bolt_rounded;
  }
  if (f.contains('atm')) return Icons.local_atm_rounded;
  if (f.contains('wifi') || f.contains('wi-fi')) return Icons.wifi_rounded;
  if (f.contains('komersial') || f.contains('retail') || f.contains('toko')) {
    return Icons.storefront_rounded;
  }
  if (f.contains('difabel') ||
      f.contains('disabilitas') ||
      f.contains('kursi roda') ||
      f.contains('wheelchair')) {
    return Icons.accessible_rounded;
  }
  if (f.contains('integrasi') || f.contains('interchange')) {
    return Icons.compare_arrows_rounded;
  }
  if (f.contains('nursery') || f.contains('laktasi') || f.contains('menyusui')) {
    return Icons.baby_changing_station_rounded;
  }
  if (f.contains('cctv') || f.contains('keamanan') || f.contains('security')) {
    return Icons.security_rounded;
  }
  return Icons.check_circle_outline_rounded;
}
