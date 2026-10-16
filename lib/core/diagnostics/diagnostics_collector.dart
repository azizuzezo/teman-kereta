import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/app_environment.dart';
import '../../features/active_trip/presentation/active_trip_controller.dart';
import '../../features/settings/presentation/settings_controller.dart';
import '../platform/native_trip_service.dart';
import 'app_log.dart';
import 'diagnostics_report.dart';

typedef AppFacts = ({String version, String build});
typedef DeviceFacts = ({
  String platform,
  String osVersion,
  String? manufacturer,
  String? model,
});

/// Everything the collector reads from the outside world. A fake in tests,
/// [PlatformDiagnosticsGateway] in the app.
abstract interface class DiagnosticsGateway {
  Future<AppFacts?> appInfo();
  Future<DeviceFacts?> device();
  Future<String?> connectivity();
  Future<bool?> locationServiceEnabled();
  Future<String?> locationPermission();

  /// Native `getPermissionStatus` map (backgroundLocation, notifications,
  /// batteryOptimizationIgnored...). Empty when unavailable.
  Future<Map<String, Object?>> nativePermissions();
  String? userId();
  String? themeMode();
  String? palette();
  String? activeTripSummary();
}

/// Builds a [DiagnosticsSnapshot]. Each probe runs in parallel with its own
/// timeout and failure is swallowed (shown as "tidak diketahui"), so
/// collecting never blocks or fails a report.
class DiagnosticsCollector {
  DiagnosticsCollector(
    this.gateway, {
    this.probeTimeout = const Duration(seconds: 3),
    DateTime Function()? clock,
    LogBuffer? buffer,
  }) : _clock = clock ?? DateTime.now,
       // ignore: prefer_initializing_formals
       _buffer = buffer;

  final DiagnosticsGateway gateway;
  final Duration probeTimeout;
  final DateTime Function() _clock;
  final LogBuffer? _buffer;

  Future<T?> _probe<T>(FutureOr<T?> Function() run, String name) async {
    try {
      return await Future<T?>.sync(run).timeout(probeTimeout);
    } on Object catch (error) {
      (_buffer ?? AppLog.buffer).add(
        LogLevel.warn,
        'Diagnostics',
        'Probe $name gagal: $error',
      );
      return null;
    }
  }

  Future<DiagnosticsSnapshot> collect({bool includeLogs = true}) async {
    final results = await Future.wait<Object?>(<Future<Object?>>[
      _probe(gateway.appInfo, 'app'),
      _probe(gateway.device, 'device'),
      _probe(gateway.connectivity, 'connectivity'),
      _probe(gateway.locationServiceEnabled, 'location_service'),
      _probe(gateway.locationPermission, 'location_permission'),
      _probe(gateway.nativePermissions, 'native_permissions'),
    ]);
    final app = results[0] as AppFacts?;
    final device = results[1] as DeviceFacts?;
    final native = (results[5] as Map<String, Object?>?) ?? const <String, Object?>{};

    final now = _clock();
    final buffer = _buffer ?? AppLog.buffer;
    final lastError = buffer.lastError;

    return DiagnosticsSnapshot(
      generatedAt: now,
      appVersion: app?.version,
      buildNumber: app?.build,
      environment: AppEnvironment.name,
      transitProvider: AppEnvironment.providerName,
      platform: device?.platform,
      osVersion: device?.osVersion,
      deviceManufacturer: device?.manufacturer,
      deviceModel: device?.model,
      locale: PlatformDispatcher.instance.locale.toLanguageTag(),
      timezone: describeTimeZone(now),
      connectivity: results[2] as String?,
      locationServiceEnabled: results[3] as bool?,
      locationPermission: results[4] as String?,
      backgroundLocationGranted: native['backgroundLocation'] as bool?,
      notificationPermissionGranted: native['notifications'] as bool?,
      batteryOptimizationExempt: native['batteryOptimizationIgnored'] as bool?,
      themeMode: _safe(gateway.themeMode),
      palette: _safe(gateway.palette),
      userId: _safe(gateway.userId),
      activeTripSummary: _safe(gateway.activeTripSummary),
      lastError: lastError?.format(),
      logLines: includeLogs ? buffer.tail(kMaxReportLogLines) : const <String>[],
      restoredLogLines: includeLogs ? buffer.restoredLines : const <String>[],
    );
  }

  String? _safe(String? Function() read) {
    try {
      return read();
    } on Object {
      return null;
    }
  }
}

/// `WIB (UTC+07:00)`: abbreviation from the OS plus the numeric offset.
String describeTimeZone(DateTime now) {
  final offset = now.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final hh = abs.inHours.toString().padLeft(2, '0');
  final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
  return '${now.timeZoneName} (UTC$sign$hh:$mm)';
}

String describeConnectivity(List<ConnectivityResult> results) {
  if (results.isEmpty || results.contains(ConnectivityResult.none)) {
    return 'tidak ada';
  }
  return results.map((r) => r.name).join('+');
}

class PlatformDiagnosticsGateway implements DiagnosticsGateway {
  PlatformDiagnosticsGateway(this._ref);

  final Ref _ref;

  @override
  Future<AppFacts?> appInfo() async {
    final info = await PackageInfo.fromPlatform();
    return (version: info.version, build: info.buildNumber);
  }

  @override
  Future<DeviceFacts?> device() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return (
        platform: 'Android',
        osVersion: '${info.version.release} (SDK ${info.version.sdkInt})',
        manufacturer: info.manufacturer,
        model: info.model,
      );
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return (
        platform: 'iOS',
        osVersion: info.systemVersion,
        manufacturer: 'Apple',
        model: info.utsname.machine,
      );
    }
    return (
      platform: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      manufacturer: null,
      model: null,
    );
  }

  @override
  Future<String?> connectivity() async =>
      describeConnectivity(await Connectivity().checkConnectivity());

  @override
  Future<bool?> locationServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<String?> locationPermission() async =>
      (await Geolocator.checkPermission()).name;

  @override
  Future<Map<String, Object?>> nativePermissions() =>
      _ref.read(nativeTripServiceProvider).getPermissionStatus();

  @override
  String? userId() {
    if (!AppEnvironment.supabaseEnabled) {
      return null;
    }
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } on Object {
      return null;
    }
  }

  @override
  String? themeMode() => _ref.read(settingsControllerProvider).themeMode.name;

  @override
  String? palette() => _ref.read(settingsControllerProvider).palette.name;

  @override
  String? activeTripSummary() {
    final session = _ref.read(activeTripControllerProvider);
    if (session == null) {
      return null;
    }
    final total = session.trip.stationIds.length;
    return 'status ${session.state.name}, stasiun ke-${session.currentStationIndex + 1} dari $total, '
        'mulai ${formatIso8601WithOffset(session.startedAt)}';
  }
}

final diagnosticsCollectorProvider = Provider<DiagnosticsCollector>((ref) {
  return DiagnosticsCollector(PlatformDiagnosticsGateway(ref));
});
