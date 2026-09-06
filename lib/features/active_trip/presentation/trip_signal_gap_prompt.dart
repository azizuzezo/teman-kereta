import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import 'active_trip_controller.dart';
import 'trip_signal_gap.dart';

/// Asks the rider to confirm a trip whose GPS trail has a hole in it —
/// "Kami mendeteksi lokasi kamu berbeda dari lokasi terakhir. Apakah kamu
/// masih di kereta?" — the next time they open the app after a signal
/// outage.
///
/// **The trip is already running when this appears, and stays running
/// unless the rider explicitly says they got off.** Dismissing the dialog
/// (tapping outside, back gesture, or just never answering) leaves tracking
/// exactly as it was: native has already caught the trip up to the rider's
/// real position, and this only offers them a chance to say otherwise. That
/// is why there is no "confirm to continue" button — continuing is the
/// default, not the reward for answering.
Future<void> showTripSignalGapPrompt(
  BuildContext context,
  WidgetRef ref,
  TripSignalGap gap,
) async {
  final controller = ref.read(activeTripControllerProvider.notifier);
  final stillOnBoard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.location_searching_rounded),
      title: const Text('Masih di kereta?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Kami mendeteksi lokasi kamu berbeda dari lokasi terakhir. '
            'Apakah kamu masih di kereta?',
          ),
          const SizedBox(height: 12),
          Text(
            'Sinyal sempat hilang ${formatDuration(gap.gap)} '
            'dan kamu berpindah sekitar ${formatDistanceMeters(gap.movedMeters)}. '
            'Perjalanan sudah kami lanjutkan otomatis ke posisi terbarumu.',
            style: Theme.of(dialogContext).textTheme.bodySmall,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Tidak, akhiri'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Ya, masih di kereta'),
        ),
      ],
    ),
  );
  // `null` means dismissed without answering — treated as "keep going",
  // same as an explicit yes.
  await controller.acknowledgeLocationGap(stillOnBoard: stillOnBoard ?? true);
}

/// Watches for a pending gap and shows [showTripSignalGapPrompt] once per
/// outage. Mixed into the app-shell watcher so it fires wherever the rider
/// happens to be in the app when they reopen it.
mixin TripSignalGapPromptMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  String? _promptedGapKey;

  void listenForSignalGapPrompts() {
    ref.listen(tripSignalGapProvider, (previous, next) {
      if (next == null || next.key == _promptedGapKey) {
        return;
      }
      if (ref.read(activeTripControllerProvider) == null) {
        return;
      }
      _promptedGapKey = next.key;
      unawaited(showTripSignalGapPrompt(context, ref, next));
    });
  }
}
