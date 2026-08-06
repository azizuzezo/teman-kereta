import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../app/config/app_environment.dart';
import '../preferences/preferences_store.dart';

/// Reports the rider's own GPS position to `public.crowd_position_reports`
/// while an Active Trip is confirmed onBoard a specific real train leg, so
/// other users can see a genuinely real (not schedule-estimated) vehicle
/// position for that trip. Entirely gated by the existing "Deteksi Otomatis
/// Naik KRL" setting (`rideDetectionEnabled`) — bundled into that consent
/// rather than a separate toggle, per an explicit product decision, since
/// enabling automatic ride detection is what authorizes this upload.
///
/// Each report is a single one-shot [Geolocator.getCurrentPosition] call on
/// a periodic timer (see `ActiveTripController`), never a continuous
/// stream — same "event/poll-driven, not raw GPS streaming" posture as the
/// rest of this app's location handling (PRD §31), just polled more often
/// since a useful shared position needs real recency. Never requests the
/// location permission itself (PRD §10: explain before any permission
/// dialog) — if it isn't already granted, a report is silently skipped,
/// same posture as [NearestStationController].
class CrowdPositionReporter {
  CrowdPositionReporter(this._store);

  final PreferencesStore _store;

  Future<String> _deviceSessionId() async {
    final existing = _store.snapshot.deviceSessionId;
    if (existing != null) {
      return existing;
    }
    final generated = const Uuid().v4();
    await _store.setDeviceSessionId(generated);
    return generated;
  }

  Future<void> reportOnce({
    required String externalTripId,
    required DateTime serviceDate,
  }) async {
    if (!AppEnvironment.supabaseEnabled) {
      return;
    }

    Position position;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }
      final permission = await Geolocator.checkPermission();
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) {
        return;
      }
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on Object {
      return;
    }

    try {
      final sessionId = await _deviceSessionId();
      await Supabase.instance.client.from('crowd_position_reports').insert(
        <String, Object?>{
          'external_trip_id': externalTripId,
          'service_date': _isoDate(serviceDate),
          'latitude': position.latitude,
          'longitude': position.longitude,
          'reported_at': DateTime.now().toUtc().toIso8601String(),
          'device_session_id': sessionId,
        },
      );
    } on Object {
      // Best-effort — a failed report must never surface to the rider or
      // interrupt their trip.
    }
  }

  String _isoDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

final crowdPositionReporterProvider = Provider<CrowdPositionReporter>((
  Ref ref,
) {
  return CrowdPositionReporter(ref.watch(preferencesStoreProvider));
});
