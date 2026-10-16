import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'app_log.dart';

const String kUnknownValue = 'tidak diketahui';

/// Max size of `log_text` accepted by the database (characters). The client
/// trims to a safer byte budget so the check constraint never trips.
const int kMaxLogTextBytes = 150 * 1024;

/// How many of the newest log lines a report carries at most.
const int kMaxReportLogLines = 300;

enum ReportCategory {
  schedule('schedule', 'Jadwal salah'),
  notification('notification', 'Notifikasi atau suara tidak berbunyi'),
  map('map', 'Peta atau posisi kereta'),
  forum('forum', 'Forum atau penyalahgunaan'),
  account('account', 'Akun atau login'),
  other('other', 'Lainnya');

  const ReportCategory(this.code, this.label);

  /// Stored in `app_reports.category`; must match the SQL check constraint.
  final String code;
  final String label;

  static ReportCategory? fromCode(String? code) {
    for (final value in values) {
      if (value.code == code) {
        return value;
      }
    }
    return null;
  }
}

/// Facts about the device and app at the moment a report is created. Every
/// field is nullable: a probe that fails or times out is shown as
/// "tidak diketahui" instead of blocking the report.
@immutable
class DiagnosticsSnapshot {
  const DiagnosticsSnapshot({
    required this.generatedAt,
    this.appName = 'Teman Kereta',
    this.appVersion,
    this.buildNumber,
    this.environment,
    this.transitProvider,
    this.platform,
    this.osVersion,
    this.deviceManufacturer,
    this.deviceModel,
    this.locale,
    this.timezone,
    this.connectivity,
    this.locationServiceEnabled,
    this.locationPermission,
    this.backgroundLocationGranted,
    this.notificationPermissionGranted,
    this.batteryOptimizationExempt,
    this.themeMode,
    this.palette,
    this.userId,
    this.activeTripSummary,
    this.lastError,
    this.logLines = const <String>[],
    this.restoredLogLines = const <String>[],
  });

  final DateTime generatedAt;
  final String appName;
  final String? appVersion;
  final String? buildNumber;
  final String? environment;
  final String? transitProvider;
  final String? platform;
  final String? osVersion;
  final String? deviceManufacturer;
  final String? deviceModel;
  final String? locale;
  final String? timezone;
  final String? connectivity;
  final bool? locationServiceEnabled;
  final String? locationPermission;
  final bool? backgroundLocationGranted;
  final bool? notificationPermissionGranted;
  final bool? batteryOptimizationExempt;
  final String? themeMode;
  final String? palette;

  /// Account uuid only, never an e-mail. Null when signed out.
  final String? userId;
  final String? activeTripSummary;
  final String? lastError;

  /// Newest log lines of this session, oldest first.
  final List<String> logLines;

  /// Lines left by the previous session (useful after a crash).
  final List<String> restoredLogLines;

  String get versionLabel => appVersion == null
      ? kUnknownValue
      : buildNumber == null
      ? appVersion!
      : '$appVersion ($buildNumber)';

  String get deviceLabel {
    final parts = <String>[
      if (deviceManufacturer != null && deviceManufacturer!.isNotEmpty)
        deviceManufacturer!,
      if (deviceModel != null && deviceModel!.isNotEmpty) deviceModel!,
    ];
    return parts.isEmpty ? kUnknownValue : parts.join(' ');
  }

  DiagnosticsSnapshot copyWith({
    List<String>? logLines,
    List<String>? restoredLogLines,
  }) {
    return DiagnosticsSnapshot(
      generatedAt: generatedAt,
      appName: appName,
      appVersion: appVersion,
      buildNumber: buildNumber,
      environment: environment,
      transitProvider: transitProvider,
      platform: platform,
      osVersion: osVersion,
      deviceManufacturer: deviceManufacturer,
      deviceModel: deviceModel,
      locale: locale,
      timezone: timezone,
      connectivity: connectivity,
      locationServiceEnabled: locationServiceEnabled,
      locationPermission: locationPermission,
      backgroundLocationGranted: backgroundLocationGranted,
      notificationPermissionGranted: notificationPermissionGranted,
      batteryOptimizationExempt: batteryOptimizationExempt,
      themeMode: themeMode,
      palette: palette,
      userId: userId,
      activeTripSummary: activeTripSummary,
      lastError: lastError,
      logLines: logLines ?? this.logLines,
      restoredLogLines: restoredLogLines ?? this.restoredLogLines,
    );
  }
}

/// A complete report as the user submits it.
@immutable
class SupportReport {
  const SupportReport({
    required this.id,
    required this.category,
    required this.message,
    required this.snapshot,
    this.contactEmail,
    this.includeLogs = true,
  });

  /// Client-generated uuid. It becomes `app_reports.id`, so a retry after a
  /// dropped connection cannot create a duplicate row.
  final String id;
  final ReportCategory category;
  final String message;

  /// Only set when the user ticked "sertakan email untuk dihubungi".
  final String? contactEmail;
  final bool includeLogs;
  final DiagnosticsSnapshot snapshot;

  /// First 8 characters of [id], upper case: what the user quotes to support.
  String get shortId => shortReportId(id);

  String get subject =>
      '[Laporan #$shortId] ${category.label} - Teman Kereta v${snapshot.appVersion ?? '?'}';

  /// Log lines that will actually be sent, capped by count and byte size,
  /// keeping the newest lines. Empty when [includeLogs] is false.
  List<String> get logLinesToSend {
    if (!includeLogs) {
      return const <String>[];
    }
    final combined = <String>[
      if (snapshot.restoredLogLines.isNotEmpty) ...<String>[
        '--- sesi sebelumnya ---',
        ...snapshot.restoredLogLines.take(60),
        '--- sesi ini ---',
      ],
      ...snapshot.logLines,
    ];
    return limitLogLines(combined);
  }

  String get logText => logLinesToSend.join('\n');
}

String shortReportId(String id) {
  final compact = id.replaceAll('-', '');
  return (compact.length <= 8 ? compact : compact.substring(0, 8))
      .toUpperCase();
}

/// Keeps the newest lines within [maxLines] and [maxBytes] (UTF-8).
List<String> limitLogLines(
  List<String> lines, {
  int maxLines = kMaxReportLogLines,
  int maxBytes = kMaxLogTextBytes,
}) {
  var start = lines.length > maxLines ? lines.length - maxLines : 0;
  var bytes = 0;
  for (var i = lines.length - 1; i >= start; i--) {
    bytes += utf8.encode(lines[i]).length + 1;
    if (bytes > maxBytes) {
      start = i + 1;
      break;
    }
  }
  return lines.sublist(start);
}

/// Renders reports as the fixed plain-text layout shown in the preview, saved
/// to the offline .txt file and mirrored by the e-mail Edge Function.
abstract final class DiagnosticsFormatter {
  static const String header = '=== TEMAN KERETA LAPORAN ===';
  static const String footer = '=== AKHIR LAPORAN ===';
  static const int formatVersion = 1;

  static String yesNo(bool? value, {String yes = 'ya', String no = 'tidak'}) =>
      value == null ? kUnknownValue : (value ? yes : no);

  /// Sections as ordered label/value rows, shared by [toText] and [toJson].
  static Map<String, List<(String, String)>> sections(SupportReport report) {
    final s = report.snapshot;
    String or(String? v) => (v == null || v.isEmpty) ? kUnknownValue : v;
    return <String, List<(String, String)>>{
      'Ringkasan': <(String, String)>[
        ('Kategori', report.category.label),
        (
          'Kontak',
          report.contactEmail == null
              ? 'tidak dicantumkan'
              : report.contactEmail!,
        ),
        (
          'Log ikut terkirim',
          report.includeLogs ? 'ya' : 'tidak (dimatikan pengguna)',
        ),
      ],
      'Perangkat': <(String, String)>[
        ('Platform', '${or(s.platform)} ${or(s.osVersion)}'),
        ('Perangkat', s.deviceLabel),
        ('Bahasa', or(s.locale)),
        ('Zona waktu', or(s.timezone)),
        ('Koneksi', or(s.connectivity)),
      ],
      'Aplikasi': <(String, String)>[
        ('Nama', s.appName),
        ('Versi', s.versionLabel),
        ('Lingkungan', or(s.environment)),
        ('Sumber data', or(s.transitProvider)),
        ('Tema', '${or(s.themeMode)} / ${or(s.palette)}'),
      ],
      'Status': <(String, String)>[
        ('Layanan lokasi', yesNo(s.locationServiceEnabled, yes: 'aktif', no: 'mati')),
        ('Izin lokasi', or(s.locationPermission)),
        (
          'Izin lokasi latar',
          yesNo(s.backgroundLocationGranted, yes: 'diberikan', no: 'tidak diberikan'),
        ),
        (
          'Izin notifikasi',
          yesNo(s.notificationPermissionGranted, yes: 'diberikan', no: 'tidak diberikan'),
        ),
        (
          'Bebas hemat baterai',
          yesNo(s.batteryOptimizationExempt),
        ),
        ('Akun', s.userId == null ? 'tidak masuk' : 'masuk (id ${s.userId})'),
        ('Perjalanan aktif', s.activeTripSummary ?? 'tidak ada'),
        ('Error terakhir', s.lastError ?? 'tidak ada'),
      ],
    };
  }

  static String toText(SupportReport report, {bool includeLogs = true}) {
    final out = StringBuffer()
      ..writeln(header)
      ..writeln('Format: $formatVersion')
      ..writeln('ID: ${report.id} (#${report.shortId})')
      ..writeln('Dibuat: ${formatIso8601WithOffset(report.snapshot.generatedAt)}')
      ..writeln();

    final all = sections(report);
    void writeSection(String name) {
      out.writeln('[$name]');
      for (final (label, value) in all[name]!) {
        out.writeln('$label: $value');
      }
      out.writeln();
    }

    writeSection('Ringkasan');
    out
      ..writeln('Pesan:')
      ..writeln(report.message.trim())
      ..writeln();
    writeSection('Perangkat');
    writeSection('Aplikasi');
    writeSection('Status');

    final lines = report.logLinesToSend;
    if (includeLogs && report.includeLogs) {
      out.writeln('[Log terbaru] (${lines.length} baris)');
      if (lines.isEmpty) {
        out.writeln('(belum ada log)');
      } else {
        lines.forEach(out.writeln);
      }
    } else {
      out.writeln('[Log terbaru]');
      out.writeln('(tidak disertakan)');
    }
    out
      ..writeln()
      ..write(footer);
    return out.toString();
  }

  /// Structured form stored in `app_reports.diagnostics` (jsonb). The log goes
  /// to its own `log_text` column and is not repeated here.
  static Map<String, Object?> toJson(SupportReport report) {
    final s = report.snapshot;
    return <String, Object?>{
      'format': formatVersion,
      'generated_at': formatIso8601WithOffset(s.generatedAt),
      'app': <String, Object?>{
        'name': s.appName,
        'version': s.appVersion,
        'build': s.buildNumber,
        'environment': s.environment,
        'transit_provider': s.transitProvider,
        'theme_mode': s.themeMode,
        'palette': s.palette,
      },
      'device': <String, Object?>{
        'platform': s.platform,
        'os_version': s.osVersion,
        'manufacturer': s.deviceManufacturer,
        'model': s.deviceModel,
        'locale': s.locale,
        'timezone': s.timezone,
        'connectivity': s.connectivity,
      },
      'status': <String, Object?>{
        'location_service_enabled': s.locationServiceEnabled,
        'location_permission': s.locationPermission,
        'background_location_granted': s.backgroundLocationGranted,
        'notification_permission_granted': s.notificationPermissionGranted,
        'battery_optimization_exempt': s.batteryOptimizationExempt,
        'user_id': s.userId,
        'active_trip': s.activeTripSummary,
        'last_error': s.lastError,
      },
      'log': <String, Object?>{
        'included': report.includeLogs,
        'line_count': report.logLinesToSend.length,
      },
    };
  }

  /// Row for `public.app_reports`. `user_id` is filled by the database from
  /// the JWT (`auth.uid()`), never sent by the client.
  static Map<String, Object?> toDbRow(SupportReport report) {
    final s = report.snapshot;
    return <String, Object?>{
      'id': report.id,
      'category': report.category.code,
      'message': report.message.trim(),
      'contact_email': report.contactEmail,
      'app_version': s.appVersion,
      'build_number': s.buildNumber,
      'platform': s.platform,
      'os_version': s.osVersion,
      'device_model': s.deviceLabel == kUnknownValue ? null : s.deviceLabel,
      'diagnostics': toJson(report),
      'log_text': report.includeLogs ? report.logText : null,
    };
  }

  /// Short body for `mailto:`; the full report travels as the attached .txt.
  static String mailtoBody(SupportReport report, {int maxChars = 1200}) {
    final text =
        'Laporan #${report.shortId} (${report.category.label}), '
        'Teman Kereta v${report.snapshot.appVersion ?? '?'}.\n\n'
        '${report.message.trim()}\n\n'
        'Berkas laporan lengkap terlampir. Jika tidak terlampir, tempel isinya di sini.';
    return text.length <= maxChars ? text : '${text.substring(0, maxChars)}...';
  }
}
