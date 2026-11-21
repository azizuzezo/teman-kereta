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

  /// Returns the sampled [Position] on success (or `null` if Supabase
  /// reporting is disabled, permission/service isn't available, or the GPS
  /// call itself failed) — this doubles as the "already have a fresh GPS
  /// sample" hook `LiveTripPositionController` piggybacks on so it never has
  /// to start a second GPS-polling timer of its own alongside this one.
  Future<Position?> reportOnce({
    required String externalTripId,
    required DateTime serviceDate,
    String? headsign,
    String? relation,
  }) async {
    if (!AppEnvironment.supabaseEnabled) {
      return null;
    }

    Position position;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }
      final permission = await Geolocator.checkPermission();
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) {
        return null;
      }
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on Object {
      return null;
    }

    await reportFix(
      externalTripId: externalTripId,
      serviceDate: serviceDate,
      latitude: position.latitude,
      longitude: position.longitude,
      at: DateTime.now(),
      speedMetersPerSecond: position.speed,
      bearingDegrees: position.heading,
      headsign: headsign,
      relation: relation,
    );
    return position;
  }

  /// Kolom `speed`/`bearing` baru ada setelah migrasi `train_live`. Bila
  /// database belum dimigrasi, laporan diulang tanpa dua kolom itu (sekali
  /// saja, lalu diingat) supaya laporan posisi tidak berhenti total.
  bool _extrasSupported = true;

  /// Mengirim satu fix GPS yang sudah ada (mis. dari pelacak native, tanpa
  /// panggilan GPS kedua) sebagai laporan posisi. Best-effort: kegagalan tidak
  /// pernah sampai ke pengguna.
  Future<void> reportFix({
    required String externalTripId,
    required DateTime serviceDate,
    required double latitude,
    required double longitude,
    required DateTime at,
    double? speedMetersPerSecond,
    double? bearingDegrees,
    String? headsign,
    String? relation,
  }) async {
    if (!AppEnvironment.supabaseEnabled) {
      return;
    }
    try {
      final sessionId = await _deviceSessionId();
      final base = <String, Object?>{
        'external_trip_id': externalTripId,
        'service_date': _isoDate(serviceDate),
        'latitude': latitude,
        'longitude': longitude,
        'reported_at': at.toUtc().toIso8601String(),
        'device_session_id': sessionId,
        'headsign': ?_clip(headsign),
        'relation': ?_clip(relation),
      };
      final speed = speedMetersPerSecond;
      final heading = bearingDegrees;
      final withExtras = <String, Object?>{
        ...base,
        // Arah dari GPS hanya berarti bila kereta benar-benar bergerak.
        if (speed != null && speed >= 0 && speed <= 60) 'speed': speed,
        if (heading != null &&
            heading >= 0 &&
            heading < 360 &&
            speed != null &&
            speed > 1.5)
          'bearing': heading,
      };
      final client = Supabase.instance.client;
      if (!_extrasSupported) {
        await client.from('crowd_position_reports').insert(base);
        return;
      }
      try {
        await client.from('crowd_position_reports').insert(withExtras);
      } on PostgrestException catch (e) {
        // PGRST204: kolom tidak ada di schema cache; 42703: undefined_column.
        if (e.code == 'PGRST204' || e.code == '42703') {
          _extrasSupported = false;
          await client.from('crowd_position_reports').insert(base);
        }
      }
    } on Object {
      // Best-effort: laporan gagal tidak boleh mengganggu perjalanan.
    }
  }

  /// Reports that the rider's train has just reached [stationCode], heading
  /// to [nextStationCode] (or, at the last stop, coming from
  /// [prevStationCode]). The server matches it to the official timetable and
  /// keeps the delay, so other riders see how late trains are running. Only
  /// for a GPS-detected arrival, never a manual "Lanjut" tap.
  Future<void> reportStationPassage({
    required String stationCode,
    required DateTime passedAt,
    String? nextStationCode,
    String? prevStationCode,
  }) async {
    if (!AppEnvironment.supabaseEnabled) return;
    if (nextStationCode == null && prevStationCode == null) return;
    try {
      final sessionId = await _deviceSessionId();
      await Supabase.instance.client.from('crowd_station_passages').insert(
        <String, Object?>{
          'station_code': stationCode,
          'next_station_code': ?nextStationCode,
          'prev_station_code': ?prevStationCode,
          'passed_at': passedAt.toUtc().toIso8601String(),
          'device_session_id': sessionId,
        },
      );
    } on Object {
      // Best-effort, same as position reports.
    }
  }

  static String? _clip(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim();
    return v.length > 80 ? v.substring(0, 80) : v;
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
