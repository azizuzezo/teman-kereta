import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_environment.dart';
import 'device_status.dart';

/// Measures one round trip in milliseconds. Throws when the server does not
/// answer in time or answers with a server error.
typedef LatencyProbe = Future<int> Function();

/// Whether the device has any network interface up (Wi-Fi, mobile, ethernet).
typedef ConnectionCheck = Future<bool> Function();

class InternetStatus {
  const InternetStatus({this.level, this.latencyMs, this.checking = false});

  /// Null until the first measurement finishes, so the UI shows "Mengukur"
  /// instead of claiming green.
  final LatencyLevel? level;
  final int? latencyMs;
  final bool checking;

  InternetStatus copyWith({
    LatencyLevel? level,
    int? latencyMs,
    bool? checking,
    bool clearLatency = false,
  }) {
    return InternetStatus(
      level: level ?? this.level,
      latencyMs: clearLatency ? null : (latencyMs ?? this.latencyMs),
      checking: checking ?? this.checking,
    );
  }
}

/// URL used for the probe. A tiny public health endpoint of the backend the
/// app really talks to, so "baik" means "the app's own server answers fast".
String latencyProbeUrl() {
  if (AppEnvironment.supabaseEnabled) {
    return '${AppEnvironment.supabaseUrl}/auth/v1/health';
  }
  if (AppEnvironment.isLocal) {
    return AppEnvironment.apiBaseUrl;
  }
  return 'https://www.gstatic.com/generate_204';
}

const _probeTimeout = Duration(seconds: 5);

final latencyProbeProvider = Provider<LatencyProbe>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: _probeTimeout,
      receiveTimeout: _probeTimeout,
      sendTimeout: _probeTimeout,
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return () async {
    final stopwatch = Stopwatch()..start();
    final response = await dio.get<String>(
      latencyProbeUrl(),
      options: Options(
        headers: <String, String>{
          if (AppEnvironment.supabaseEnabled)
            'apikey': AppEnvironment.supabaseAnonKey,
        },
      ),
    );
    stopwatch.stop();
    if ((response.statusCode ?? 0) >= 500) {
      throw StateError('Server error ${response.statusCode}');
    }
    return stopwatch.elapsedMilliseconds;
  };
});

final connectionCheckProvider = Provider<ConnectionCheck>((ref) {
  return () async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  };
});

/// Real round-trip latency to the backend plus offline detection. Refresh is
/// driven by the Home page (about every 15 s, only while Home is visible and
/// the app is in the foreground); this notifier never schedules anything.
class InternetStatusController extends Notifier<InternetStatus> {
  bool _warm = false;

  @override
  InternetStatus build() => const InternetStatus();

  Future<void> refresh() async {
    if (state.checking) {
      return;
    }
    // Keep the last level while checking so the tile does not flicker.
    state = state.copyWith(checking: true);

    final bool connected;
    try {
      connected = await ref.read(connectionCheckProvider)();
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(checking: false);
      }
      return;
    }
    if (!ref.mounted) {
      return;
    }
    if (!connected) {
      _warm = false;
      state = const InternetStatus(level: LatencyLevel.offline);
      return;
    }

    int? latency;
    try {
      latency = await _measure();
    } on Object {
      latency = null;
    }
    if (!ref.mounted) {
      return;
    }
    state = InternetStatus(
      level: classifyLatency(hasConnection: true, latencyMs: latency),
      latencyMs: latency,
    );
  }

  /// The very first request of a session pays for DNS and the TLS handshake,
  /// which is not what the user's connection feels like afterwards. A slow
  /// first reading is therefore measured once more on the warm connection.
  Future<int> _measure() async {
    final probe = ref.read(latencyProbeProvider);
    final first = await probe();
    if (_warm || first < latencyGoodBelowMs) {
      _warm = true;
      return first;
    }
    _warm = true;
    return probe();
  }
}

final internetStatusProvider =
    NotifierProvider<InternetStatusController, InternetStatus>(
      InternetStatusController.new,
    );
