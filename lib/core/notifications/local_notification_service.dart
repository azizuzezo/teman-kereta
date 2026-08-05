import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';

class LocalNotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    this.onShown,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

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
    final prefix = isDemo ? 'Data Demo • ' : '';
    final body = remainingStops == 0
        ? 'Periksa kondisi sekitar sebelum turun di $destination.'
        : 'Bersiap menuju $destination.';
    await _showAndLog(
      type: 'stop_alert',
      id: 4100 + remainingStops,
      title: '$prefix$title',
      body: body,
      channelId: 'trip_alerts',
      channelName: 'Peringatan perjalanan',
      channelDescription: 'Peringatan stasiun tujuan dan transit',
      payload: '/active-trip',
      vibrate: vibrate,
      sound: sound,
    );
  }

  Future<void> showTransferAlert({
    required String stationName,
    required String? instruction,
    required bool isDemo,
    bool vibrate = true,
    bool sound = true,
  }) async {
    final prefix = isDemo ? 'Data Demo • ' : '';
    await _showAndLog(
      type: 'transfer_alert',
      id: 4200,
      title: '${prefix}Saatnya transit di $stationName',
      body: instruction ?? 'Turun di $stationName dan lanjutkan ke kereta berikutnya.',
      channelId: 'trip_alerts',
      channelName: 'Peringatan perjalanan',
      channelDescription: 'Peringatan stasiun tujuan dan transit',
      payload: '/active-trip',
      vibrate: vibrate,
      sound: sound,
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
    final prefix = isDemo ? 'Data Demo • ' : '';
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
        ),
      ),
      payload: payload,
    );
    onShown?.call(type, title, body);
  }
}

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  Ref ref,
) {
  return LocalNotificationService(
    onShown: (type, title, body) {
      unawaited(
        ref.read(appDatabaseProvider).logNotification(
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
