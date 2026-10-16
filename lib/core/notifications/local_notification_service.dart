import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../platform/native_trip_service.dart';
import '../utils/geo.dart';
import 'alarm_service.dart';
import 'alert_audio_plan.dart';
import 'tts_service.dart';

class LocalNotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    this.onShown,
    this._tts,
    this._alarm,
    NativeTripService? native,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _native = native ?? const NativeTripService();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Plays the recorded voice line and the bell on Android (see
  /// [_showAndLog]): the system cannot tell the app when a notification
  /// sound ends, nor send it to a headset only.
  final NativeTripService _native;

  /// True where the native `AlertAudioPlayer` exists. Everywhere else the
  /// notification's own sound plays and the bell is a timer (see
  /// [_showAndLog]).
  bool get _usesNativeAudio =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Optional — when supplied, alerts that carry a spoken announcement also
  /// call [TtsService.speak] alongside `_plugin.show`, gated on the same
  /// `sound` flag as the notification itself (no separate voice toggle).
  final TtsService? _tts;

  /// Optional — plays `assets/alarm.mp3` after the spoken notification
  /// sound finishes, for alerts that pass `alarmDelay` (see [_showAndLog]).
  /// Non-Android only: on Android the native player does this with a real
  /// completion callback.
  final AlarmService? _alarm;

  /// Length of `remaining_station_1.wav` — the pre-recorded "1 stasiun lagi
  /// menuju ..." voice line (see `android/app/src/main/res/raw` and
  /// `ios/Runner/Sounds`). iOS plays it as the notification's own sound and
  /// has no callback for "notification sound finished playing", so there the
  /// alarm cue is still delayed by the clip's known length. (Android no
  /// longer relies on this: that delay started at `notify()`, before the
  /// system had begun the sound, so the bell cut into the voice's last words.)
  static const _remainingStationOneVoiceDuration = Duration(
    milliseconds: 6920,
  );

  /// Same idea as [_remainingStationOneVoiceDuration], for
  /// `remaining_transit_1.wav`.
  static const _remainingTransitOneVoiceDuration = Duration(
    milliseconds: 4520,
  );

  /// Called after a notification is shown, so the caller (see
  /// [localNotificationServiceProvider]) can keep "Pusat notifikasi"
  /// backed by a real log instead of this service reaching into the
  /// database itself.
  final void Function(String type, String title, String body)? onShown;

  bool _initialized = false;

  /// Flat white TK monogram — see `android/app/src/main/res/drawable/
  /// ic_stat_tk.xml` for why a notification icon has to be a silhouette.
  static const _smallIconResource = '@drawable/ic_stat_tk';

  /// The full-colour app logo, allowed here because Android does not mask
  /// the large icon.
  static const _largeIconResource = '@mipmap/ic_launcher';

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }
    // `@mipmap/ic_launcher` is the wrong kind of image for this slot:
    // Android masks a notification's small icon down to its alpha channel,
    // so a full-colour launcher icon renders as a featureless white square.
    // `ic_stat_tk` is the flat TK silhouette that slot actually wants; the
    // colour logo comes back as the large icon in [_showAndLog].
    const settings = InitializationSettings(
      android: AndroidInitializationSettings(_smallIconResource),
      // Every `request*` is off here on purpose. iOS shows its permission
      // prompt the moment the plugin initialises unless told not to, and
      // this service initialises lazily on the first alert — which would put
      // the dialog in front of the rider at an arbitrary moment. Asking is
      // [requestPermission]'s job, driven by onboarding, exactly as it is on
      // Android.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      // Covers both "tapped the notification body" and "tapped its
      // 'Matikan alarm' action" — either way, the rider has noticed, so the
      // alarm cue (see [AlarmService]) should stop. Harmless no-op if
      // nothing is playing.
      onDidReceiveNotificationResponse: (response) {
        unawaited(_alarm?.stop());
      },
    );
    await _deleteRetiredChannels();
    _initialized = true;
  }

  /// Drops the old per-alert channels whose own sound was the voice line;
  /// see [retiredAlertChannelIds]. Harmless when a channel does not exist.
  Future<void> _deleteRetiredChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return;
    }
    for (final id in retiredAlertChannelIds) {
      try {
        await android.deleteNotificationChannel(channelId: id);
      } on Object {
        // Cosmetic cleanup only: never let it block the alert.
      }
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    // Badge is left out deliberately: TK never sets one, so asking for it
    // would be requesting a capability the app doesn't use.
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  Future<void> showStopAlert({
    required int remainingStops,
    required String destination,
    required bool isDemo,
    bool vibrate = true,
    bool sound = true,
    bool log = true,
  }) async {
    final title = remainingStops == 0
        ? 'Tujuan telah tiba'
        : '$remainingStops stasiun lagi';
    // isDemo no longer changes notification copy — this app never surfaces
    // "demo" wording to the user — but the parameter stays so callers
    // (e.g. ActiveTripController) don't need a separate code path for
    // demo vs. real trips.
    const prefix = '';
    final body = remainingStops == 0
        ? 'Periksa kondisi sekitar sebelum turun di $destination.'
        : 'Bersiap menuju $destination.';
    final spokenText = remainingStops == 0
        ? 'Hampir sampai tujuan, $destination.'
        : '$remainingStops stasiun lagi menuju $destination.';
    final customSound = stopAlertVoice(remainingStops);
    final channelName = switch (customSound) {
      arrivalVoice => 'Tiba di tujuan',
      String() => '$remainingStops stasiun sebelum tujuan',
      null => 'Peringatan perjalanan',
    };
    await _showAndLog(
      type: 'stop_alert',
      id: 4100 + remainingStops,
      title: '$prefix$title',
      body: body,
      channelId: alertChannelId(customSound),
      channelName: channelName,
      channelDescription: 'Peringatan stasiun tujuan dan transit',
      payload: '/active-trip',
      vibrate: vibrate,
      sound: sound,
      customSoundResource: customSound,
      spokenText: spokenText,
      alarmDelay: bellFollowsVoice(remainingStops)
          ? _remainingStationOneVoiceDuration
          : null,
      log: log,
    );
  }

  /// Repeating countdown fired at each of 3/2/1 stops before a transfer
  /// boundary — mirrors [showStopAlert]'s destination countdown, using a
  /// distinct id range (`4150 + remainingStops`) so each remaining-stop
  /// count gets its own notification instead of replacing the previous one.
  Future<void> showTransferApproachingAlert({
    required int remainingStops,
    required String stationName,
    required bool isDemo,
    bool vibrate = true,
    bool sound = true,
    bool log = true,
  }) async {
    final customSound = transferApproachingVoice(remainingStops);
    final channelName = customSound == null
        ? 'Peringatan perjalanan'
        : '$remainingStops stasiun sebelum transit';
    await _showAndLog(
      type: 'transfer_approaching',
      id: 4150 + remainingStops,
      title: '$remainingStops stasiun lagi menuju transit',
      body: 'Bersiap transit di $stationName.',
      channelId: alertChannelId(customSound),
      channelName: channelName,
      channelDescription: 'Peringatan stasiun tujuan dan transit',
      payload: '/active-trip',
      vibrate: vibrate,
      sound: sound,
      customSoundResource: customSound,
      spokenText:
          '$remainingStops stasiun lagi menuju transit di $stationName.',
      alarmDelay: bellFollowsVoice(remainingStops)
          ? _remainingTransitOneVoiceDuration
          : null,
      log: log,
    );
  }

  Future<void> showTransferAlert({
    required String stationName,
    required String? instruction,
    required bool isDemo,
    bool vibrate = true,
    bool sound = true,
    bool log = true,
  }) async {
    // isDemo no longer changes notification copy — this app never surfaces
    // "demo" wording to the user — but the parameter stays so callers
    // (e.g. ActiveTripController) don't need a separate code path for
    // demo vs. real trips.
    const prefix = '';
    await _showAndLog(
      type: 'transfer_alert',
      id: 4200,
      title: '${prefix}Saatnya transit di $stationName',
      body:
          instruction ??
          'Turun di $stationName dan lanjutkan ke kereta berikutnya.',
      channelId: alertChannelId(transferReminderVoice),
      channelName: 'Tiba di stasiun transit',
      channelDescription: 'Peringatan stasiun tujuan dan transit',
      payload: '/active-trip',
      vibrate: vibrate,
      sound: sound,
      customSoundResource: transferReminderVoice,
      spokenText: 'Saatnya transit di $stationName.',
      log: log,
    );
  }

  /// Arrival at the destination. The trip finishes on its own at this
  /// point (see `ActiveTripController._autoCompleteOnArrival`), so this is
  /// the rider's summary — travel time, distance, average speed — not a
  /// "bersiap turun" warning. Copy and channel are kept identical to
  /// `TripNotifier.showArrivalAlert` (native), which fires instead of this
  /// one whenever native is the side that detected the arrival.
  Future<void> showArrivalAlert({
    required String destination,
    required Duration duration,
    required double distanceMeters,
    bool vibrate = true,
    bool sound = true,
    bool log = true,
  }) async {
    final averageSpeedKmh = duration.inSeconds > 0
        ? (distanceMeters / 1000) / (duration.inSeconds / 3600)
        : null;
    await _showAndLog(
      type: 'trip_arrived',
      id: 4100,
      title: 'Selamat, kamu tiba di $destination',
      body: '${formatDuration(duration)} • ${formatDistanceMeters(distanceMeters)}'
          ' • rata-rata ${formatSpeedKmh(averageSpeedKmh)}',
      channelId: alertChannelId(arrivalVoice),
      channelName: 'Tiba di tujuan',
      channelDescription: 'Peringatan stasiun tujuan dan transit',
      payload: '/trip-complete',
      vibrate: vibrate,
      sound: sound,
      customSoundResource: arrivalVoice,
      spokenText: 'Selamat, kamu sudah tiba di $destination.',
      log: log,
    );
  }

  Future<void> showRideDetectedAlert({
    required String stationName,
    required bool isStrongMatch,
  }) async {
    await _showAndLog(
      type: 'ride_detected',
      id: 4400,
      title: isStrongMatch
          ? 'Sepertinya kamu sedang naik kereta'
          : 'Kamu baru saja meninggalkan $stationName',
      body: isStrongMatch
          ? 'Ketuk untuk memulai panduan perjalanan.'
          : 'Ketuk untuk konfirmasi apakah kamu sedang naik KRL.',
      channelId: 'ride_detection',
      channelName: 'Deteksi naik KRL',
      channelDescription: 'Konfirmasi dugaan naik kereta otomatis',
      payload: '/ride-detection',
    );
  }

  Future<void> showMissedDestinationAlert({
    required String destination,
    required bool isDemo,
    bool vibrate = true,
    bool sound = true,
    bool log = true,
  }) async {
    // isDemo no longer changes notification copy — this app never surfaces
    // "demo" wording to the user — but the parameter stays so callers
    // (e.g. ActiveTripController) don't need a separate code path for
    // demo vs. real trips.
    const prefix = '';
    await _showAndLog(
      type: 'missed_destination',
      id: 4300,
      title: '${prefix}Sepertinya kamu melewati $destination',
      body: 'Buka aplikasi untuk mencari rute kembali ke $destination.',
      channelId: alertChannelId(missedDestinationVoice),
      channelName: 'Tujuan terlewat',
      channelDescription: 'Peringatan stasiun tujuan dan transit',
      payload: '/active-trip',
      importance: Importance.max,
      priority: Priority.max,
      vibrate: vibrate,
      sound: sound,
      customSoundResource: missedDestinationVoice,
      log: log,
    );
  }

  /// Shows a notification for an incoming Firebase Cloud Messaging foreground
  /// message (see `PushTokenRegistrar` / `main.dart`'s
  /// `FirebaseMessaging.onMessage` listener). Generic by design — the
  /// title/body are whatever the server-side `send-push-notification` Edge
  /// Function sent, unlike the other `show*Alert` methods here which all
  /// have fixed, locally-generated copy.
  Future<void> showRemotePush({
    required String title,
    required String body,
  }) async {
    await _showAndLog(
      type: 'server_push',
      id: 4600,
      title: title,
      body: body,
      channelId: 'server_push',
      channelName: 'Notifikasi server',
      channelDescription:
          'Notifikasi push yang dikirim dari server Teman Kereta',
      payload: '/notifications',
    );
  }

  Future<void> showServiceDisruptionAlert({
    required String title,
    required String description,
  }) async {
    await _showAndLog(
      type: 'service_alert',
      id: 4500,
      title: 'Peringatan Layanan KRL • $title',
      body: description,
      channelId: 'service_alerts',
      channelName: 'Gangguan & Info Layanan',
      channelDescription: 'Notifikasi langsung saat ada gangguan lintasan KRL',
      payload: '/notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
  }

  Future<void> _showAndLog({
    required String type,
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String payload,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    bool vibrate = true,
    bool sound = true,
    String? customSoundResource,
    String? spokenText,
    /// When set, plays the bundled alarm cue (see [AlarmService]) after this
    /// delay — used for the "1 stasiun lagi" transfer/arrival countdowns,
    /// timed to land after their spoken notification sound finishes (see
    /// [_remainingStationOneVoiceDuration]).
    Duration? alarmDelay,
    /// False for the in-app "Tes suara peringatan" previews — they should
    /// sound exactly like the real thing but must not leave a trail in
    /// "Pusat notifikasi", which is a record of real trip events.
    bool log = true,
  }) async {
    await initialize();
    // Android: the voice line (then the bell, when [alarmDelay] marks one)
    // is played by the native player, not by the notification channel. It
    // starts the bell from the voice's real completion, and sends both to
    // the headset only when one is connected. Started before `show` so a
    // notification failure can never silence the announcement.
    final nativeAudio = sound && customSoundResource != null && _usesNativeAudio;
    if (nativeAudio) {
      unawaited(
        _native.playAlertAudio(
          voice: customSoundResource,
          bell: alarmDelay != null,
        ),
      );
    }
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentSound: sound,
          sound: (sound && customSoundResource != null)
              ? _darwinSoundFile(customSoundResource)
              : null,
        ),
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          icon: _smallIconResource,
          largeIcon: const DrawableResourceAndroidBitmap(_largeIconResource),
          importance: importance,
          priority: priority,
          enableVibration: vibrate,
          // Silent when the native player speaks this alert (its channel is
          // silent too, see [alertChannelId]); a channel's own sound could
          // neither be sequenced with the bell nor sent to a headset only.
          playSound: sound && customSoundResource == null,
          // A quick way to silence the alarm cue without unlocking into the
          // app — tapping it fires the same
          // `onDidReceiveNotificationResponse` callback as tapping the
          // notification body (see [initialize]). `showsUserInterface: true`
          // is required here: Android otherwise delivers the tap as a
          // background broadcast, which a backgrounded/frozen app process
          // (see Android's cached-app freezer) may not act on before the
          // alarm has already played through — confirmed on-device, tapping
          // the action did nothing until this was set.
          actions: (sound && alarmDelay != null)
              ? const <AndroidNotificationAction>[
                  AndroidNotificationAction(
                    'stop_alarm',
                    'Matikan alarm',
                    cancelNotification: false,
                    showsUserInterface: true,
                  ),
                ]
              : null,
        ),
      ),
      payload: payload,
    );
    // Alerts with a bundled recording speak through it; the system TTS is
    // only a fallback when there is none.
    if (sound && spokenText != null && customSoundResource == null) {
      unawaited(_tts?.speak(spokenText));
    }
    // iOS: the recording is the notification's own sound and cannot report
    // when it ends, so the bell is delayed by the clip's known length.
    if (sound && alarmDelay != null && !nativeAudio) {
      unawaited(Future<void>.delayed(alarmDelay, () => _alarm?.play()));
    }
    if (log) {
      onShown?.call(type, title, body);
    }
  }

  /// The same alert sound, named the way each platform wants it.
  ///
  /// Android resolves `res/raw` by bare resource name; iOS resolves a file in
  /// the app bundle and needs the extension. The files themselves are the
  /// identical assets, kept in `ios/Runner/Sounds/` for the iOS build —
  /// `.wav` for every alert except `terlewat`, which is an `.mp3`.
  ///
  /// If a file is missing from the bundle, iOS falls back to the default
  /// notification sound rather than failing — quieter than intended, never a
  /// silent alert.
  static String _darwinSoundFile(String resource) =>
      resource == 'terlewat' ? '$resource.mp3' : '$resource.wav';
}

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  Ref ref,
) {
  return LocalNotificationService(
    tts: ref.read(ttsServiceProvider),
    alarm: ref.read(alarmServiceProvider),
    onShown: (type, title, body) {
      unawaited(
        ref
            .read(appDatabaseProvider)
            .logNotification(
              NotificationLogEntriesCompanion.insert(
                notificationType: type,
                title: title,
                body: body,
                sentAt: DateTime.now(),
              ),
            ),
      );
    },
  );
});
