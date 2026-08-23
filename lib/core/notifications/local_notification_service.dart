import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';
import 'tts_service.dart';

class LocalNotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    this.onShown,
    this._tts,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Optional — when supplied, alerts that carry a spoken announcement also
  /// call [TtsService.speak] alongside `_plugin.show`, gated on the same
  /// `sound` flag as the notification itself (no separate voice toggle).
  final TtsService? _tts;

  /// Called after a notification is shown, so the caller (see
  /// [localNotificationServiceProvider]) can keep "Pusat notifikasi"
  /// backed by a real log instead of this service reaching into the
  /// database itself.
  final void Function(String type, String title, String body)? onShown;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<void> showStopAlert({
    required int remainingStops,
    required String destination,
    required bool isDemo,
    bool vibrate = true,
    bool sound = true,
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
    final customSound = remainingStops == 0
        ? 'arrive_station'
        : (remainingStops >= 1 && remainingStops <= 3)
            ? 'remaining_station_$remainingStops'
            : null;
    final channelName = switch (customSound) {
      'arrive_station' => 'Tiba di tujuan',
      String() => '$remainingStops stasiun sebelum tujuan',
      null => 'Peringatan perjalanan',
    };
    await _showAndLog(
      type: 'stop_alert',
      id: 4100 + remainingStops,
      title: '$prefix$title',
      body: body,
      channelId: customSound == null ? 'trip_alerts' : 'trip_alert_$customSound',
      channelName: channelName,
      channelDescription: 'Peringatan stasiun tujuan dan transit',
      payload: '/active-trip',
      vibrate: vibrate,
      sound: sound,
      customSoundResource: customSound,
      spokenText: spokenText,
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
  }) async {
    final customSound = (remainingStops >= 1 && remainingStops <= 3)
        ? 'remaining_transit_$remainingStops'
        : null;
    final channelName = customSound == null
        ? 'Peringatan perjalanan'
        : '$remainingStops stasiun sebelum transit';
    await _showAndLog(
      type: 'transfer_approaching',
      id: 4150 + remainingStops,
      title: '$remainingStops stasiun lagi menuju transit',
      body: 'Bersiap transit di $stationName.',
      channelId: customSound == null ? 'trip_alerts' : 'trip_alert_$customSound',
      channelName: channelName,
      channelDescription: 'Peringatan stasiun tujuan dan transit',
      payload: '/active-trip',
      vibrate: vibrate,
      sound: sound,
      customSoundResource: customSound,
      spokenText:
          '$remainingStops stasiun lagi menuju transit di $stationName.',
    );
  }

  Future<void> showTransferAlert({
    required String stationName,
    required String? instruction,
    required bool isDemo,
    bool vibrate = true,
    bool sound = true,
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
      channelId: 'trip_alert_transit_reminder',
      channelName: 'Tiba di stasiun transit',
      channelDescription: 'Peringatan stasiun tujuan dan transit',
      payload: '/active-trip',
      vibrate: vibrate,
      sound: sound,
      customSoundResource: 'transit_reminder',
      spokenText: 'Saatnya transit di $stationName.',
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
      channelId: 'trip_alerts',
      channelName: 'Peringatan perjalanan',
      channelDescription: 'Peringatan stasiun tujuan dan transit',
      payload: '/active-trip',
      importance: Importance.max,
      priority: Priority.max,
      vibrate: vibrate,
      sound: sound,
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
  }) async {
    await initialize();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: importance,
          priority: priority,
          enableVibration: vibrate,
          playSound: sound,
          sound: (sound && customSoundResource != null)
              ? RawResourceAndroidNotificationSound(customSoundResource)
              : null,
        ),
      ),
      payload: payload,
    );
    if (sound && spokenText != null) {
      unawaited(_tts?.speak(spokenText));
    }
    onShown?.call(type, title, body);
  }
}

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  Ref ref,
) {
  return LocalNotificationService(
    tts: ref.read(ttsServiceProvider),
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
