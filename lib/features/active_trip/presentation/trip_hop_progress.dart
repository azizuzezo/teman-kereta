import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the rider is on the hop between the station just reached and the
/// next one, as measured natively along the real track
/// (`TripProgressEngine.hopProgress`).
class TripHopProgress {
  const TripHopProgress({
    required this.departed,
    this.distanceToNextMeters,
    this.fraction,
  });

  /// The train has left the station just reached, so the trip reads
  /// "dalam perjalanan A → B" instead of "stasiun saat ini: A".
  final bool departed;

  /// Track distance left to the next station, null until the first fix.
  final double? distanceToNextMeters;

  /// 0-1 along the track from the station just reached to the next one.
  final double? fraction;

  static TripHopProgress fromNative(Map<Object?, Object?> native) {
    return TripHopProgress(
      departed: native['departed'] == true,
      distanceToNextMeters: (native['distanceToNextMeters'] as num?)
          ?.toDouble(),
      fraction: (native['hopFraction'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TripHopProgress &&
      other.departed == departed &&
      other.distanceToNextMeters == distanceToNextMeters &&
      other.fraction == fraction;

  @override
  int get hashCode => Object.hash(departed, distanceToNextMeters, fraction);
}

/// In-memory mirror of native's hop progress for the current app run, like
/// `tripLocationStatusProvider` — not part of the persisted session.
class TripHopProgressController extends Notifier<TripHopProgress?> {
  @override
  TripHopProgress? build() => null;

  void set(TripHopProgress? progress) {
    state = progress;
  }
}

final tripHopProgressProvider =
    NotifierProvider<TripHopProgressController, TripHopProgress?>(
      TripHopProgressController.new,
    );
