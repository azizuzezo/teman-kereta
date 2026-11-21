import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/location/crowd_position_reporter.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/platform/native_trip_service.dart';
import '../../../core/preferences/preferences_store.dart';
import '../../../core/utils/geo.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/estimated_trip_builder.dart';
import '../../intercity/data/intercity_repository.dart';
import '../../intercity/domain/intercity_trip.dart';
import '../../live_map/presentation/native_gps_fix.dart';
import '../../settings/presentation/settings_controller.dart';
import 'active_trip_stations.dart';
import 'trip_battery_warning.dart';
import 'trip_hop_progress.dart';
import 'trip_signal_gap.dart';

/// How often the rider's own position is reported while onBoard, when
/// "Deteksi Otomatis Naik KRL" is enabled — see [CrowdPositionReporter].
/// Purely a crowd-sourced-position upload to Supabase, unrelated to this
/// trip's own progress tracking (see `_nativeSyncInterval` for that).
const _crowdReportInterval = Duration(seconds: 5);

/// How often Dart polls the native `ActiveTripLocationService` for the
/// continuously-updated distance/speed/station-progress it now owns (see
/// `TripProgressEngine` on the native side — station advancement and
/// stop/transfer notifications fire from there, not from Dart, since that
/// service keeps running even after Android tears down the Flutter engine,
/// e.g. when the app is swiped from Recents). This timer just refreshes the
/// UI/local snapshot with whatever native has already decided.
const _nativeSyncInterval = Duration(seconds: 4);

/// Fix native yang lebih tua dari ini tidak dilaporkan; laporan jatuh kembali
/// ke satu panggilan GPS baru.
const _crowdFixMaxAge = Duration(seconds: 12);

class ActiveTripController extends Notifier<ActiveTripSession?> {
  late final PreferencesStore _store;
  Timer? _crowdReportTimer;
  DateTime? _lastReportedFixAt;
  Timer? _nativeSyncTimer;

  /// The other way(s) round for the current trip, built once per trip.
  (String, List<TransitTrip>)? _alternativeRoutes;
  bool _switchingRoute = false;

  /// Session the rider already answered "Ya, masih di kereta" for. Later
  /// outages on the same trip (every tunnel, every dead zone) are cleared
  /// silently instead of asking again.
  String? _gapConfirmedSessionId;

  @override
  ActiveTripSession? build() {
    _store = ref.watch(preferencesStoreProvider);
    ref.onDispose(_stopTimers);
    ref.listen(settingsControllerProvider, _pushSettingsToNative);
    final encoded = _store.snapshot.activeTripSnapshot;
    if (encoded == null) {
      return null;
    }
    try {
      final restored = ActiveTripSession.fromJson(
        jsonDecode(encoded) as Map<String, Object?>,
      );
      // A restart mid-trip (app process killed and relaunched, not just
      // swiped from Recents — `stopWithTask=false` already keeps the
      // foreground service alive across that) must not silently stop
      // tracking. `native.update()` re-dispatches `ActiveTripLocationService`
      // — a cheap, idempotent no-op if it's already running, but the only
      // thing that actually restarts it if the whole process died with it.
      if (restored.state == ActiveTripState.arrived) {
        // Arrived while the app was closed, and Dart had already synced
        // that state before the process died — no timer will run for it
        // (`arrived` isn't a tracked state), so finish it here instead.
        unawaited(Future.microtask(complete));
      } else if (_isTrackedState(restored.state)) {
        _startTimers();
        unawaited(_syncToNative(restored));
        // An async function still runs synchronously up to its first
        // `await` — calling `_refreshFromNative` directly here would read
        // `state` before `build()` has finished returning it, throwing
        // "uninitialized provider". `Future.microtask` defers it to run
        // right after `build()` completes instead.
        unawaited(Future.microtask(_refreshFromNative));
      }
      return restored;
    } on Object {
      unawaited(_store.setActiveTripSnapshot(null));
      return null;
    }
  }

  /// The stations a trip's native tracker and screens resolve ids against:
  /// the KRL list, plus the intercity stations for an intercity ride. Falls
  /// back to the cached KRL list offline, like every other station lookup.
  Future<List<Station>> _stationsFor(ActiveTripSession? session) async {
    final base = await ref.read(stationListProvider.future);
    if (session == null || !isIntercityTrip(session.trip)) return base;
    final catalog = await ref.read(intercityCatalogProvider.future);
    return mergeIntercityStations(base, catalog);
  }

  /// Stop-count alerts ("3 stasiun lagi") are a KRL idea. An intercity ride
  /// has stops tens of minutes apart and is announced by time instead (see
  /// `IntercityRideController`), so the station-count alerts are switched off
  /// for it, on this side and, through the value sent to native, there too.
  int _stopAlertThresholdFor(
    ActiveTripSession? session,
    AppSettings settings,
  ) => session != null && isIntercityTrip(session.trip)
      ? 0
      : settings.stopAlertThreshold;

  bool _isTrackedState(ActiveTripState state) => switch (state) {
    ActiveTripState.onBoard ||
    ActiveTripState.approachingTransfer ||
    ActiveTripState.transferring ||
    ActiveTripState.approachingDestination => true,
    _ => false,
  };

  void _pushSettingsToNative(AppSettings? previous, AppSettings next) {
    final current = state;
    if (current == null || !_isTrackedState(current.state)) {
      return;
    }
    if (previous != null &&
        previous.stopAlertThreshold == next.stopAlertThreshold &&
        previous.vibrationEnabled == next.vibrationEnabled &&
        previous.soundEnabled == next.soundEnabled) {
      return;
    }
    unawaited(
      ref
          .read(nativeTripServiceProvider)
          .updateSettings(
            stopAlertThreshold: _stopAlertThresholdFor(current, next),
            vibrationEnabled: next.vibrationEnabled,
            soundEnabled: next.soundEnabled,
          ),
    );
  }

  void _startTimers() {
    _crowdReportTimer?.cancel();
    _crowdReportTimer = Timer.periodic(_crowdReportInterval, (_) {
      unawaited(_reportCrowdPositionIfEligible());
    });
    _nativeSyncTimer?.cancel();
    _nativeSyncTimer = Timer.periodic(_nativeSyncInterval, (_) {
      unawaited(_refreshFromNative());
    });
  }

  void _stopTimers() {
    _crowdReportTimer?.cancel();
    _crowdReportTimer = null;
    _nativeSyncTimer?.cancel();
    _nativeSyncTimer = null;
  }

  /// Pulls the latest continuously-tracked distance/speed/station-progress
  /// from native (`TripProgressEngine`, via `NativeStateStore`) and merges
  /// it into the local session — never regresses `currentStationIndex`
  /// backward (a manual "Lanjut" advance may have already pushed Dart ahead
  /// of what native has processed yet). Never re-fires notifications here:
  /// native already fired them itself at the moment it decided to advance.
  Future<void> _refreshFromNative() async {
    final current = state;
    if (current == null || !_isTrackedState(current.state)) {
      return;
    }
    final native = await ref
        .read(nativeTripServiceProvider)
        .getActiveTripFullState();
    if (!ref.mounted) return;
    final latest = state;
    if (latest == null || !_isTrackedState(latest.state)) {
      return;
    }

    final nativeIndex = (native['currentStationIndex'] as num?)?.toInt();
    final nativeStateName = native['state'] as String?;
    // When native decided this, not when we got round to reading it — a
    // trip that arrived while the app was closed must be timed from the
    // arrival, not from the next app launch.
    final nativeUpdatedAtMs = native['updatedAtEpochMs'] as int?;
    final nativeDistance = (native['distanceMeters'] as num?)?.toDouble();
    final nativeSpeedKmh = (native['speedKmh'] as num?)?.toDouble();

    var updated = latest;
    var changed = false;
    if (nativeIndex != null && nativeIndex >= latest.currentStationIndex) {
      final parsedState = nativeStateName == null
          ? null
          : ActiveTripState.values
                .where((s) => s.name == nativeStateName)
                .firstOrNull;
      if (nativeIndex != latest.currentStationIndex ||
          parsedState != latest.state) {
        // GPS moved the trip exactly one station on: a trustworthy arrival
        // time for the timetable-accuracy contribution. A jump of several
        // stations (catching up after a signal gap) has no such time.
        if (nativeIndex == latest.currentStationIndex + 1) {
          _reportStationPassage(
            latest,
            nativeIndex,
            nativeUpdatedAtMs != null && nativeUpdatedAtMs > 0
                ? DateTime.fromMillisecondsSinceEpoch(nativeUpdatedAtMs)
                : ref.read(clockProvider).now(),
          );
        }
        updated = updated.copyWith(
          currentStationIndex: nativeIndex,
          state: parsedState ?? updated.state,
          updatedAt: nativeUpdatedAtMs != null && nativeUpdatedAtMs > 0
              ? DateTime.fromMillisecondsSinceEpoch(nativeUpdatedAtMs)
              : ref.read(clockProvider).now(),
        );
        changed = true;
      }
    }
    if (nativeDistance != null && nativeDistance > updated.distanceMeters) {
      updated = updated.copyWith(distanceMeters: nativeDistance);
      changed = true;
    }
    if (nativeSpeedKmh != null && nativeSpeedKmh != updated.currentSpeedKmh) {
      updated = updated.copyWith(currentSpeedKmh: nativeSpeedKmh);
      changed = true;
    }
    if (changed) {
      state = updated;
      await _store.setActiveTripSnapshot(jsonEncode(updated.toJson()));
      if (updated.state == ActiveTripState.arrived) {
        // Reaching the destination ends the trip on its own — no "Selesai"
        // tap required. Native has already announced it (see
        // `TripNotifier.showArrivalAlert`); this closes the session, writes
        // the history row and lets the app shell route to the recap.
        await complete();
        return;
      }
    }

    // A signal gap native recorded while we weren't looking. Surfacing it
    // is all that happens here — `TripProgressEngine` has already caught
    // the trip up to wherever the rider really is, so this only decides
    // whether to *ask* them to confirm it (see `TripSignalGapPrompt`).
    final gap = TripSignalGap.fromNative(native['locationGap']);
    if (gap != null && updated.id == _gapConfirmedSessionId) {
      await ref.read(nativeTripServiceProvider).acknowledgeLocationGap();
      if (!ref.mounted) return;
    } else if (gap != null && ref.read(tripSignalGapProvider)?.key != gap.key) {
      ref.read(tripSignalGapProvider.notifier).set(gap);
    }

    final hop = TripHopProgress.fromNative(native);
    if (hop != ref.read(tripHopProgressProvider)) {
      ref.read(tripHopProgressProvider.notifier).set(hop);
    }

    final locationStatus = native['locationStatus'] as String?;
    if (locationStatus != ref.read(tripLocationStatusProvider)) {
      ref.read(tripLocationStatusProvider.notifier).set(locationStatus);
    }

    final lat = (native['latitude'] as num?)?.toDouble();
    final lng = (native['longitude'] as num?)?.toDouble();
    final locationAtMs = native['locationAtEpochMs'] as int?;
    if (lat != null && lng != null && locationAtMs != null) {
      ref
          .read(latestNativeGpsFixProvider.notifier)
          .set(
            NativeGpsFix(
              latitude: lat,
              longitude: lng,
              at: DateTime.fromMillisecondsSinceEpoch(locationAtMs),
              speedMetersPerSecond: (native['speedMetersPerSecond'] as num?)
                  ?.toDouble(),
              bearingDegrees: (native['bearingDegrees'] as num?)?.toDouble(),
            ),
          );
      await _switchRouteIfGpsDisagrees(lat, lng);
    }
  }

  /// Metres from (lat, lng) to the straight segment between two stations.
  static double _distanceToSegment(
    double lat,
    double lng,
    Station a,
    Station b,
  ) {
    const ky = 110574.0;
    const kx = 110700.0;
    final ax = a.longitude * kx, ay = a.latitude * ky;
    final dx = b.longitude * kx - ax, dy = b.latitude * ky - ay;
    final px = lng * kx - ax, py = lat * ky - ay;
    final len = dx * dx + dy * dy;
    final t = len == 0 ? 0.0 : ((px * dx + py * dy) / len).clamp(0.0, 1.0);
    final cx = px - t * dx, cy = py - t * dy;
    return math.sqrt(cx * cx + cy * cy);
  }

  /// The rider says which way round their train goes. Switches the trip to
  /// that route (keeping progress) when it differs, and stops asking.
  Future<void> chooseRoute(String viaName) async {
    final current = state;
    if (current == null) return;
    if (current.trip.routeVia == viaName) {
      final updated = current.copyWith(routeConfirmed: true);
      state = updated;
      await _store.setActiveTripSnapshot(jsonEncode(updated.toJson()));
      return;
    }
    final alternative = (await _alternativesFor(
      current,
    )).where((t) => t.routeVia == viaName).firstOrNull;
    if (alternative == null || !ref.mounted) return;
    await _switchToRoute(alternative);
  }

  Future<List<TransitTrip>> _alternativesFor(ActiveTripSession session) async {
    final cached = _alternativeRoutes;
    if (cached != null && cached.$1 == session.trip.id) return cached.$2;
    if (session.trip.routeVia == null) return const <TransitTrip>[];
    final stations = await _stationsFor(session);
    final trips = <TransitTrip>[
      for (final via in otherRouteVias(session.trip, stations))
        ?alternativeEstimatedTrip(
          trip: session.trip,
          allStations: stations,
          viaName: via,
        ),
    ];
    _alternativeRoutes = (session.trip.id, trips);
    return trips;
  }

  /// Replaces the trip with [route], keeping the rider at the same station:
  /// both routes share every stop up to where they split.
  Future<void> _switchToRoute(TransitTrip route) async {
    final current = state;
    if (current == null) return;
    final here = current.currentStationId;
    final index = here == null ? -1 : route.stationIds.indexOf(here);
    final updated = current.copyWith(
      trip: route,
      currentStationIndex: index < 0 ? current.currentStationIndex : index,
      routeConfirmed: true,
      updatedAt: ref.read(clockProvider).now(),
    );
    _alternativeRoutes = null;
    state = updated;
    await _persistAndSync(updated);
  }

  /// Once the train passes the point where the two ways round split (e.g.
  /// Jatinegara: on to Matraman, or on to Pondok Jati), GPS shows which one
  /// it took. When it is clearly near the other route's next stop and not
  /// ours, the trip follows the train.
  Future<void> _switchRouteIfGpsDisagrees(double lat, double lng) async {
    final current = state;
    if (current == null ||
        _switchingRoute ||
        current.trip.routeVia == null ||
        !_isTrackedState(current.state)) {
      return;
    }
    _switchingRoute = true;
    try {
      final alternatives = await _alternativesFor(current);
      if (alternatives.isEmpty || !ref.mounted) return;
      final stations = await _stationsFor(current);
      final byId = {for (final s in stations) s.id: s};
      final ours = current.trip.stationIds;
      double? distanceTo(String id) {
        final s = byId[id];
        return s == null
            ? null
            : haversineMeters(lat, lng, s.latitude, s.longitude);
      }

      for (final alternative in alternatives) {
        final theirs = alternative.stationIds;
        var split = 0;
        while (split < ours.length &&
            split < theirs.length &&
            ours[split] == theirs[split]) {
          split++;
        }
        // Only around the split: the rider is at, or just past, the last
        // shared stop.
        if (split == 0 ||
            split >= ours.length ||
            split >= theirs.length ||
            current.currentStationIndex < split - 2 ||
            current.currentStationIndex > split) {
          continue;
        }
        // Distance from the rider to each route's track just past the
        // split (stop before, the next stop, the one after), as straight
        // segments between stations. Right after Jatinegara the two lines
        // are only a few hundred metres apart, so compare lines, not stops.
        double? toLine(List<String> ids) {
          final pts = <Station>[
            for (var i = split - 1; i <= split + 1 && i < ids.length; i++)
              ?byId[ids[i]],
          ];
          if (pts.length < 2) return null;
          var best = double.infinity;
          for (var i = 1; i < pts.length; i++) {
            final d = _distanceToSegment(lat, lng, pts[i - 1], pts[i]);
            if (d < best) best = d;
          }
          return best;
        }

        final toTheirs = toLine(theirs);
        final toOurs = toLine(ours);
        if (toTheirs == null || toOurs == null) continue;
        final splitStop = distanceTo(ours[split - 1]) ?? 0;
        if (splitStop > 300 && toTheirs < 150 && toOurs > toTheirs + 150) {
          await _switchToRoute(alternative);
          return;
        }
      }
    } on Object {
      // Never let a route check disturb the trip.
    } finally {
      _switchingRoute = false;
    }
  }

  /// Public entry point for the same native reconciliation the periodic
  /// timer does — called on foreground resume, where waiting up to 4s for
  /// the next tick is exactly the lag that makes a trip look frozen after
  /// the app has been in the background.
  Future<void> syncFromNativeNow() => _refreshFromNative();

  Future<void> _reportCrowdPositionIfEligible() async {
    if (!ref.read(settingsControllerProvider).rideDetectionEnabled) {
      return;
    }
    final current = state;
    if (current == null || !_isTrackedState(current.state)) {
      return;
    }
    if (current.trip.isDemo ||
        current.trip.id.startsWith(IntercityTripRef.prefix)) {
      return; // Demo data never reports; intercity trains are not on the map.
    }
    final leg = current.currentRailLeg;
    var externalTripId = leg?.externalTripId;
    var serviceDate = leg?.serviceDate;
    if (externalTripId == null || serviceDate == null) {
      // An estimated trip (no timetable id): report under the hop the train
      // is on, so riders of the same train still add up to one position.
      final from = current.currentStationId;
      final to = current.nextStationId;
      if (from == null || to == null) return;
      externalTripId = 'seg:$from>$to';
      final now = ref.read(clockProvider).now();
      serviceDate = DateTime(now.year, now.month, now.day);
    }
    final reporter = ref.read(crowdPositionReporterProvider);
    // Pakai fix dari pelacak native bila masih segar: tidak perlu panggilan GPS
    // kedua, jadi laporan tiap beberapa detik tidak menguras baterai.
    final fix = ref.read(latestNativeGpsFixProvider);
    final now = ref.read(clockProvider).now();
    if (fix != null && now.difference(fix.at).abs() <= _crowdFixMaxAge) {
      // Fix yang sama sudah dilaporkan; tunggu yang baru.
      if (fix.at == _lastReportedFixAt) return;
      _lastReportedFixAt = fix.at;
      await reporter.reportFix(
        externalTripId: externalTripId,
        serviceDate: serviceDate,
        latitude: fix.latitude,
        longitude: fix.longitude,
        at: fix.at,
        speedMetersPerSecond: fix.speedMetersPerSecond,
        bearingDegrees: fix.bearingDegrees,
        headsign: leg?.headsign,
        relation: leg?.relation,
      );
      return;
    }
    await reporter.reportOnce(
      externalTripId: externalTripId,
      serviceDate: serviceDate,
      headsign: leg?.headsign,
      relation: leg?.relation,
    );
  }

  /// Tells the server the train has just reached the station at [index], so
  /// it can compare against the timetable (see
  /// [CrowdPositionReporter.reportStationPassage]). Same consent gate as the
  /// position reports.
  void _reportStationPassage(
    ActiveTripSession session,
    int index,
    DateTime at,
  ) {
    if (!ref.read(settingsControllerProvider).rideDetectionEnabled) return;
    if (session.trip.isDemo ||
        session.trip.id.startsWith(IntercityTripRef.prefix)) {
      return;
    }
    final ids = session.trip.stationIds;
    if (index <= 0 || index >= ids.length) return;
    unawaited(
      ref
          .read(crowdPositionReporterProvider)
          .reportStationPassage(
            stationCode: ids[index],
            passedAt: at,
            nextStationCode: ids.elementAtOrNull(index + 1),
            prevStationCode: index + 1 < ids.length ? null : ids[index - 1],
          ),
    );
  }

  /// Manual "Lanjut" fallback for when automatic (native, GPS-proximity)
  /// detection misses a stop — same station-machine logic native runs, kept
  /// here for the user-initiated path. Pushes the result back to native via
  /// [_persistAndSync] so its own next-station tracking resyncs too.
  Future<void> advanceStop() async {
    final current = state;
    if (current == null || current.trip.stationIds.isEmpty) {
      return;
    }

    final lastIndex = current.trip.stationIds.length - 1;

    if (current.state == ActiveTripState.arrived ||
        current.currentStationIndex >= lastIndex) {
      await _markMissedDestination(current);
      return;
    }

    final nextIndex = current.currentStationIndex + 1;
    final remaining = lastIndex - nextIndex;
    final boundary = current.trip.transferBoundaries
        .where((candidate) => candidate.index >= nextIndex)
        .firstOrNull;
    final nextState = switch (boundary) {
      final b? when b.index == nextIndex => ActiveTripState.transferring,
      final b? when b.index - nextIndex <= 3 =>
        ActiveTripState.approachingTransfer,
      _ when remaining <= 0 => ActiveTripState.arrived,
      _ when remaining <= 3 => ActiveTripState.approachingDestination,
      _ => ActiveTripState.onBoard,
    };
    final now = ref.read(clockProvider).now();
    final hop = await _hopDistanceAndSpeed(
      fromStationId: current.trip.stationIds[current.currentStationIndex],
      toStationId: current.trip.stationIds[nextIndex],
      elapsed: now.difference(current.updatedAt),
    );
    if (!ref.mounted) return;
    final updated = current.copyWith(
      currentStationIndex: nextIndex,
      state: nextState,
      updatedAt: now,
      distanceMeters: current.distanceMeters + hop.distanceMeters,
      currentSpeedKmh: hop.speedKmh ?? current.currentSpeedKmh,
    );
    state = updated;
    await _persistAndSync(updated);

    final settings = ref.read(settingsControllerProvider);
    if (nextState == ActiveTripState.arrived) {
      // Same contract as the native path above: arrival announces itself
      // with the recap and finishes the trip, rather than parking on an
      // "arrived" screen waiting to be dismissed.
      unawaited(
        ref
            .read(localNotificationServiceProvider)
            .showArrivalAlert(
              destination: _stationName(current.trip.destinationStationId),
              duration: now.difference(current.startedAt),
              distanceMeters: updated.distanceMeters,
              vibrate: settings.vibrationEnabled,
              sound: settings.soundEnabled,
            ),
      );
      await complete();
      return;
    }
    if (nextState == ActiveTripState.transferring) {
      unawaited(
        ref
            .read(localNotificationServiceProvider)
            .showTransferAlert(
              stationName: _stationName(current.trip.stationIds[nextIndex]),
              instruction: boundary?.instruction,
              isDemo: current.trip.isDemo,
              vibrate: settings.vibrationEnabled,
              sound: settings.soundEnabled,
            ),
      );
    } else if (boundary != null) {
      // Repeating countdown at 3/2/1 stops before the transfer boundary,
      // mirroring the destination countdown below.
      final stopsToTransfer = boundary.index - nextIndex;
      if (stopsToTransfer > 0 &&
          stopsToTransfer <= _stopAlertThresholdFor(current, settings)) {
        unawaited(
          ref
              .read(localNotificationServiceProvider)
              .showTransferApproachingAlert(
                remainingStops: stopsToTransfer,
                stationName: _stationName(
                  current.trip.stationIds[boundary.index],
                ),
                isDemo: current.trip.isDemo,
                vibrate: settings.vibrationEnabled,
                sound: settings.soundEnabled,
              ),
        );
      }
    } else if (remaining <= _stopAlertThresholdFor(current, settings)) {
      unawaited(
        ref
            .read(localNotificationServiceProvider)
            .showStopAlert(
              remainingStops: remaining,
              destination: _stationName(current.trip.destinationStationId),
              isDemo: current.trip.isDemo,
              vibrate: settings.vibrationEnabled,
              sound: settings.soundEnabled,
            ),
      );
    }
  }

  /// Straight-line distance for the just-completed station-to-station hop,
  /// plus the average speed implied by how long that hop actually took —
  /// only used by the manual [advanceStop] fallback above; the automatic
  /// path's distance/speed come continuously from native GPS fixes instead.
  Future<({double distanceMeters, double? speedKmh})> _hopDistanceAndSpeed({
    required String fromStationId,
    required String toStationId,
    required Duration elapsed,
  }) async {
    List<Station> stations;
    try {
      // `stationListProvider`, not the raw `stationProvider` — this falls
      // back to the locally cached station list (PRD §19) when there's no
      // signal, instead of always needing a live Supabase round trip.
      stations = await _stationsFor(state);
    } on Object {
      // A station-lookup failure must never block the manual "Lanjut"
      // fallback from advancing — just skip the distance/speed estimate.
      return (distanceMeters: 0.0, speedKmh: null);
    }
    if (!ref.mounted) return (distanceMeters: 0.0, speedKmh: null);
    final byId = {for (final station in stations) station.id: station};
    final from = byId[fromStationId];
    final to = byId[toStationId];
    if (from == null || to == null) {
      return (distanceMeters: 0.0, speedKmh: null);
    }
    final meters = haversineMeters(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    final speedKmh = elapsed.inSeconds > 0
        ? (meters / 1000) / (elapsed.inSeconds / 3600)
        : null;
    return (distanceMeters: meters, speedKmh: speedKmh);
  }

  Future<void> _markMissedDestination(ActiveTripSession current) async {
    final updated = current.copyWith(
      state: ActiveTripState.missedDestination,
      updatedAt: ref.read(clockProvider).now(),
    );
    state = updated;
    await _persistAndSync(updated);
    final settings = ref.read(settingsControllerProvider);
    unawaited(
      ref
          .read(localNotificationServiceProvider)
          .showMissedDestinationAlert(
            destination: _stationName(current.trip.destinationStationId),
            isDemo: current.trip.isDemo,
            vibrate: settings.vibrationEnabled,
            sound: settings.soundEnabled,
          ),
    );
  }

  Future<void> cancel() async {
    final current = state;
    if (current != null) {
      state = current.copyWith(
        state: ActiveTripState.cancelled,
        updatedAt: ref.read(clockProvider).now(),
      );
    }
    await ref.read(nativeTripServiceProvider).stop();
    _stopTimers();
    ref.read(tripSignalGapProvider.notifier).set(null);
    ref.read(tripHopProgressProvider.notifier).set(null);
    await _store.setActiveTripSnapshot(null);
    state = null;
  }

  Future<void> complete() async {
    final current = state;
    if (current == null) {
      return;
    }
    final completed = current.copyWith(
      state: ActiveTripState.completed,
      // An already-`arrived` session is stamped with the moment it actually
      // reached the destination; re-stamping it here would inflate the
      // recap's travel time by however long the rider took to look.
      updatedAt: current.state == ActiveTripState.arrived
          ? current.updatedAt
          : ref.read(clockProvider).now(),
    );
    state = completed;
    await ref.read(nativeTripServiceProvider).stop();
    _stopTimers();
    ref.read(tripSignalGapProvider.notifier).set(null);
    ref.read(tripHopProgressProvider.notifier).set(null);
    await _store.setActiveTripSnapshot(null);
    await _logHistory(current);
  }

  Future<void> _logHistory(ActiveTripSession session) async {
    final trip = session.trip;
    final lineName = trip.legs
        .where((leg) => leg.mode == TransportMode.commuterRail)
        .map((leg) => leg.lineName)
        .whereType<String>()
        .firstOrNull;
    try {
      await ref
          .read(appDatabaseProvider)
          .logCompletedTrip(
            CompletedTripsCompanion.insert(
              id: session.id,
              originStationId: trip.originStationId,
              originName: _stationName(trip.originStationId),
              destinationStationId: trip.destinationStationId,
              destinationName: _stationName(trip.destinationStationId),
              lineName: Value(lineName),
              departedAt: trip.departureAt,
              arrivedAt: trip.arrivalAt,
              isDemo: Value(trip.isDemo),
              completedAt: ref.read(clockProvider).now(),
            ),
          );
    } on Object {
      // History is a convenience, not load-bearing — losing one row must
      // never block the user from finishing their trip.
    }
  }

  void dismissCompleted() {
    if (state?.state == ActiveTripState.completed) {
      state = null;
    }
  }

  /// [routeConfirmed] false: the trip was started without the rider picking
  /// which way round it goes (quick start, automatic ride detection), so the
  /// trip page asks and GPS can still switch it (see [chooseRoute]).
  Future<void> start(
    TransitTrip trip, {
    String? finalDestinationQuery,
    bool routeConfirmed = true,
  }) async {
    final now = ref.read(clockProvider).now();
    _alternativeRoutes = null;
    final session = ActiveTripSession(
      routeConfirmed: routeConfirmed || trip.routeVia == null,
      id: const Uuid().v4(),
      trip: trip,
      state: ActiveTripState.onBoard,
      currentStationIndex: 0,
      startedAt: now,
      updatedAt: now,
      confirmedByUser: true,
      finalDestinationQuery: finalDestinationQuery,
    );
    state = session;
    await _store.setActiveTripSnapshot(jsonEncode(session.toJson()));
    if (!ref.mounted) return;
    await _syncToNative(session, isStart: true);
    if (!ref.mounted) return;
    _startTimers();
  }

  /// Backs the "Perbarui lokasi" button. Nudges the native tracker into
  /// rebuilding its location subscription and taking one immediate
  /// high-accuracy fix, then pulls whatever native concluded.
  ///
  /// Explicitly *not* the mechanism trip progress relies on: automatic
  /// tracking (a fix every ~3s, plus a watchdog that rebuilds the
  /// subscription after 90s of silence) is the source of truth, and this
  /// button feeds the very same pipeline. It exists so a rider who can see
  /// the app is behind doesn't have to wait for the watchdog.
  Future<void> refreshLocation() async {
    final current = state;
    if (current == null || !_isTrackedState(current.state)) {
      return;
    }
    await ref.read(nativeTripServiceProvider).refreshLocation();
    if (!ref.mounted) return;
    // The forced fix takes a moment to come back from the OS; the periodic
    // sync below picks it up either way, this just shortens the wait.
    await _refreshFromNative();
    if (!ref.mounted) return;
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!ref.mounted) return;
    await _refreshFromNative();
  }

  /// Dismisses the "masih di kereta?" prompt. [stillOnBoard] is recorded
  /// only to decide what happens next: false ends the trip, true (and
  /// dismissing without answering at all) leaves it running exactly as it
  /// was — the rider is never required to confirm anything for tracking to
  /// continue.
  Future<void> acknowledgeLocationGap({required bool stillOnBoard}) async {
    ref.read(tripSignalGapProvider.notifier).set(null);
    if (stillOnBoard) {
      _gapConfirmedSessionId = state?.id;
    }
    await ref.read(nativeTripServiceProvider).acknowledgeLocationGap();
    if (!stillOnBoard) {
      await cancel();
    }
  }

  Future<void> toggleLowBatteryMode() async {
    final current = state;
    if (current == null) {
      return;
    }
    final updated = current.copyWith(
      lowBatteryMode: !current.lowBatteryMode,
      updatedAt: ref.read(clockProvider).now(),
    );
    state = updated;
    await _persistAndSync(updated);
  }

  Future<void> _persistAndSync(ActiveTripSession session) async {
    await _store.setActiveTripSnapshot(jsonEncode(session.toJson()));
    await _syncToNative(session);
  }

  /// Best-effort — never lets a station-fetch or platform-channel failure
  /// block the trip itself from starting/advancing locally. Native tracking
  /// (continuous GPS distance/notifications) is an enhancement on top of the
  /// core Dart-side trip flow, not a dependency of it.
  Future<void> _syncToNative(
    ActiveTripSession session, {
    bool isStart = false,
  }) async {
    try {
      // `stationListProvider`, not the raw `stationProvider`: a live
      // Supabase call here has no offline fallback, and failing right at
      // `isStart` (no signal at the exact moment "Mulai perjalanan" is
      // tapped — the common case on a KRL platform) used to mean native
      // GPS tracking and stop notifications never started at all, silently.
      // `stationListProvider` falls back to the locally cached station list
      // (PRD §19) so a bad-signal start still gets native tracking running.
      final stations = await _stationsFor(session);
      if (!ref.mounted) return;
      final settings = ref.read(settingsControllerProvider);
      final native = ref.read(nativeTripServiceProvider);
      if (isStart) {
        final warnings = await native.start(
          session,
          stations: stations,
          stopAlertThreshold: _stopAlertThresholdFor(session, settings),
          vibrationEnabled: settings.vibrationEnabled,
          soundEnabled: settings.soundEnabled,
        );
        if (ref.mounted &&
            warnings.contains(NativeTripService.batteryOptimizationWarning)) {
          ref.read(tripBatteryWarningProvider.notifier).set(true);
        }
      } else {
        await native.update(
          session,
          stations: stations,
          stopAlertThreshold: _stopAlertThresholdFor(session, settings),
          vibrationEnabled: settings.vibrationEnabled,
          soundEnabled: settings.soundEnabled,
        );
      }
    } on Object {
      // See doc comment above.
    }
  }

  // Prefers the real (Supabase) station list — demoStations alone doesn't
  // know most real station codes (e.g. 'KLDB'/'CUK'), so notifications and
  // the trip-history record this feeds (`_logHistory` above) would otherwise
  // permanently persist a raw code instead of a real station name.
  String _stationName(String stationId) {
    final session = state;
    if (session != null && isIntercityTrip(session.trip)) {
      final catalog = ref.read(intercityCatalogProvider).value;
      final name = catalog?.stations[stationId]?.name;
      if (name != null) return name;
    }
    final fromLive = ref
        .read(stationListProvider)
        .value
        ?.where((station) => station.id == stationId)
        .firstOrNull
        ?.name;
    if (fromLive != null) {
      return fromLive;
    }
    return demoStations
            .where((station) => station.id == stationId)
            .firstOrNull
            ?.name ??
        stationId;
  }
}

final activeTripControllerProvider =
    NotifierProvider<ActiveTripController, ActiveTripSession?>(
      ActiveTripController.new,
    );
