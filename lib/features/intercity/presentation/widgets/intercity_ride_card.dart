import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/notifications/alert_audio_plan.dart';
import '../../../../core/widgets/tk_components.dart';
import '../intercity_ride_controller.dart';

/// "1 j 20 m" / "45 m": the time left, for the big number.
String formatIntercityEta(Duration eta) {
  final minutes = (eta.inSeconds / 60).ceil().clamp(0, 99999);
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return hours == 0 ? '$minutes m' : '$hours j ${rest.toString().padLeft(2, '0')} m';
}

/// The estimate and the three reminders of an intercity ride, on the active
/// trip screen.
class IntercityRideCard extends ConsumerWidget {
  const IntercityRideCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final ride = ref.watch(intercityRideControllerProvider);
    final eta = ride.eta;
    return TkCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.train_rounded, size: 18, color: tk.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ride.serviceName ?? 'Kereta antar kota',
                  style: textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            eta == null
                ? 'Mencari posisi kereta…'
                : eta.onTrack
                ? 'Sisa perjalanan ${eta.remainingKm.toStringAsFixed(0)} km, '
                      'kecepatan dipakai ${eta.speedKmh.round()} km/jam.'
                : 'Posisimu belum terbaca di jalur kereta ini; estimasi memakai '
                      'jarak lurus ke tujuan.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text('Pengingat', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              for (final km in intercityReminderKm)
                TkPill(
                  label: '$km km',
                  icon: ride.firedKm.contains(km)
                      ? Icons.check_circle_rounded
                      : Icons.notifications_none_rounded,
                  tone: ride.firedKm.contains(km)
                      ? TkPillTone.success
                      : TkPillTone.neutral,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pengingat dihitung dari sisa jarak sepanjang rel, bukan garis lurus. '
            'Jam tiba hanya estimasi karena jadwal resmi tidak tersedia.',
            style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
          ),
        ],
      ),
    );
  }
}
