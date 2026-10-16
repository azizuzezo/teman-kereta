/// Where trip alert audio goes right now.
enum AudioRoute {
  /// No headset: the phone's own speaker, loud (alarm behaviour).
  speaker,

  /// A headset is connected: the voice line and the bell play only there.
  headset,
}

/// Snapshot of the alert audio route, from `NativeTripService.audioRoute()`.
///
/// [deviceKind] is one of `wired`, `usb`, `bluetooth`, `bluetooth_sco`,
/// `ble`, `hearing_aid`, and null on the speaker.
class AudioRouteInfo {
  const AudioRouteInfo({
    this.route = AudioRoute.speaker,
    this.deviceKind,
    this.deviceName,
  });

  /// Anything unreadable is the speaker: the safe, audible default.
  factory AudioRouteInfo.fromNative(Map<String, Object?>? map) {
    if (map == null || map['route'] != 'headset') {
      return speaker;
    }
    String? text(String key) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      return null;
    }

    return AudioRouteInfo(
      route: AudioRoute.headset,
      deviceKind: text('deviceKind'),
      deviceName: text('deviceName'),
    );
  }

  /// What a platform without the native side (tests, iOS, desktop) reports.
  static const speaker = AudioRouteInfo();

  final AudioRoute route;
  final String? deviceKind;
  final String? deviceName;

  bool get isHeadset => route == AudioRoute.headset;

  /// Line for the "Tes suara" page.
  String get statusText {
    if (!isHeadset) return 'Suara lewat speaker ponsel';
    final name = deviceName;
    return name == null
        ? 'Tersambung ke headset'
        : 'Tersambung ke headset ($name)';
  }

  @override
  bool operator ==(Object other) =>
      other is AudioRouteInfo &&
      other.route == route &&
      other.deviceKind == deviceKind &&
      other.deviceName == deviceName;

  @override
  int get hashCode => Object.hash(route, deviceKind, deviceName);
}
