import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/native_trip_service.dart';

/// Live OS permission snapshot (`getPermissionStatus` on the native side).
/// Shared by the Profile tab (row subtitles) and the location page, so both
/// read the same source. Invalidate it after returning from a screen that can
/// change a permission.
final devicePermissionStatusProvider =
    FutureProvider.autoDispose<Map<String, Object?>>((ref) {
      return ref.watch(nativeTripServiceProvider).getPermissionStatus();
    });

/// One-line summary of the location permission for a settings row.
String locationPermissionSummary(Map<String, Object?> status) {
  final foreground = status['foregroundLocation'];
  if (foreground is! bool) {
    return 'Atur izin dan deteksi naik KRL';
  }
  if (!foreground) {
    return 'Izin belum diberikan';
  }
  final background = status['backgroundLocation'] == true;
  return background
      ? 'Diizinkan, termasuk di latar belakang'
      : 'Diizinkan saat aplikasi dibuka';
}

/// One-line summary of the notification permission for a settings row.
String notificationPermissionSummary(Map<String, Object?> status) {
  final granted = status['notifications'];
  if (granted is! bool) {
    return 'Ketuk untuk meminta izin';
  }
  return granted ? 'Diizinkan' : 'Belum diizinkan, ketuk untuk mengizinkan';
}
