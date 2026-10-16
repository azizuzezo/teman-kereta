import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/diagnostics/app_log.dart';
import 'package:teman_kereta/core/diagnostics/diagnostics_collector.dart';
import 'package:teman_kereta/core/diagnostics/diagnostics_report.dart';

DiagnosticsSnapshot _snapshot({
  List<String> logLines = const <String>['L1', 'L2'],
  List<String> restored = const <String>[],
  String? userId = 'user-uuid-1',
  bool? battery = false,
}) {
  return DiagnosticsSnapshot(
    generatedAt: DateTime(2026, 10, 15, 10, 22, 11),
    appVersion: '1.0.17',
    buildNumber: '18',
    environment: 'remote',
    transitProvider: 'local_supabase',
    platform: 'Android',
    osVersion: '14 (SDK 34)',
    deviceManufacturer: 'Xiaomi',
    deviceModel: '2201117TG',
    locale: 'id-ID',
    timezone: 'WIB (UTC+07:00)',
    connectivity: 'wifi',
    locationServiceEnabled: true,
    locationPermission: 'whileInUse',
    backgroundLocationGranted: false,
    notificationPermissionGranted: true,
    batteryOptimizationExempt: battery,
    themeMode: 'system',
    palette: 'navyKrl',
    userId: userId,
    activeTripSummary: 'status onBoard, stasiun ke-3 dari 12',
    lastError: '2026-10-15T10:20:00.000+07:00 E [flutter] boom',
    logLines: logLines,
    restoredLogLines: restored,
  );
}

SupportReport _report({
  DiagnosticsSnapshot? snapshot,
  bool includeLogs = true,
  String? contact,
}) => SupportReport(
  id: '3f2b8c1e-7a4d-4e0a-9b1f-2c5d6e7f8a90',
  category: ReportCategory.notification,
  message: '  Suara tidak keluar saat 1 stasiun lagi.  ',
  snapshot: snapshot ?? _snapshot(),
  includeLogs: includeLogs,
  contactEmail: contact,
);

void main() {
  group('DiagnosticsFormatter.toText', () {
    test('has the fixed header, sections in order, and footer', () {
      final text = DiagnosticsFormatter.toText(_report());
      final lines = text.split('\n');
      expect(lines.first, '=== TEMAN KERETA LAPORAN ===');
      expect(lines.last, '=== AKHIR LAPORAN ===');

      final order = <String>[
        '[Ringkasan]',
        'Pesan:',
        '[Perangkat]',
        '[Aplikasi]',
        '[Status]',
        '[Log terbaru] (2 baris)',
      ];
      var cursor = -1;
      for (final marker in order) {
        final index = lines.indexOf(marker);
        expect(index, greaterThan(cursor), reason: '$marker out of order');
        cursor = index;
      }
    });

    test('contains the facts a support engineer needs', () {
      final text = DiagnosticsFormatter.toText(_report());
      expect(text, contains('ID: 3f2b8c1e-7a4d-4e0a-9b1f-2c5d6e7f8a90 (#3F2B8C1E)'));
      expect(text, contains('Kategori: Notifikasi atau suara tidak berbunyi'));
      expect(text, contains('Suara tidak keluar saat 1 stasiun lagi.'));
      expect(text, contains('Platform: Android 14 (SDK 34)'));
      expect(text, contains('Perangkat: Xiaomi 2201117TG'));
      expect(text, contains('Versi: 1.0.17 (18)'));
      expect(text, contains('Sumber data: local_supabase'));
      expect(text, contains('Izin lokasi latar: tidak diberikan'));
      expect(text, contains('Bebas hemat baterai: tidak'));
      expect(text, contains('Akun: masuk (id user-uuid-1)'));
      expect(text, contains('Error terakhir: 2026-10-15T10:20:00.000+07:00 E [flutter] boom'));
      expect(text, matches(RegExp(r'Dibuat: 2026-10-15T10:22:11\.\d{3}[+-]\d{2}:\d{2}')));
    });

    test('never prints an e-mail unless a contact was chosen', () {
      expect(
        DiagnosticsFormatter.toText(_report()),
        contains('Kontak: tidak dicantumkan'),
      );
      expect(
        DiagnosticsFormatter.toText(_report(contact: 'budi@mail.com')),
        contains('Kontak: budi@mail.com'),
      );
    });

    test('unknown probes read "tidak diketahui", not null', () {
      final text = DiagnosticsFormatter.toText(
        _report(
          snapshot: DiagnosticsSnapshot(generatedAt: DateTime(2026, 10, 15)),
        ),
      );
      expect(text, isNot(contains('null')));
      expect(text, contains('Bebas hemat baterai: tidak diketahui'));
      expect(text, contains('Versi: tidak diketahui'));
      expect(text, contains('Akun: tidak masuk'));
    });

    test('logs switched off: header says so and no log lines are included', () {
      final report = _report(includeLogs: false);
      final text = DiagnosticsFormatter.toText(report);
      expect(text, contains('Log ikut terkirim: tidak (dimatikan pengguna)'));
      expect(text, contains('(tidak disertakan)'));
      expect(text, isNot(contains('L1')));
      expect(report.logText, isEmpty);
    });

    test('previous-session lines are separated from this session', () {
      final report = _report(
        snapshot: _snapshot(restored: <String>['OLD1'], logLines: <String>['NEW1']),
      );
      final lines = report.logLinesToSend;
      expect(lines, <String>[
        '--- sesi sebelumnya ---',
        'OLD1',
        '--- sesi ini ---',
        'NEW1',
      ]);
    });
  });

  group('limitLogLines', () {
    test('keeps the newest lines when over the line cap', () {
      final lines = List<String>.generate(10, (i) => 'l$i');
      expect(limitLogLines(lines, maxLines: 3), <String>['l7', 'l8', 'l9']);
    });

    test('keeps the newest lines when over the byte cap', () {
      final lines = <String>['a' * 50, 'b' * 50, 'c' * 50];
      final out = limitLogLines(lines, maxBytes: 110);
      expect(out, <String>['b' * 50, 'c' * 50]);
    });

    test('multi-byte text is measured in bytes, not characters', () {
      final lines = <String>['é' * 40, 'é' * 40]; // 80 bytes each
      expect(limitLogLines(lines, maxBytes: 100), hasLength(1));
    });
  });

  group('DiagnosticsFormatter.toJson / toDbRow', () {
    test('db row matches the app_reports columns and omits the e-mail by default', () {
      final row = DiagnosticsFormatter.toDbRow(_report());
      expect(row.keys.toSet(), <String>{
        'id',
        'category',
        'message',
        'contact_email',
        'app_version',
        'build_number',
        'platform',
        'os_version',
        'device_model',
        'diagnostics',
        'log_text',
      });
      expect(row['id'], '3f2b8c1e-7a4d-4e0a-9b1f-2c5d6e7f8a90');
      expect(row['category'], 'notification');
      expect(row['message'], 'Suara tidak keluar saat 1 stasiun lagi.');
      expect(row['contact_email'], isNull);
      expect(row['device_model'], 'Xiaomi 2201117TG');
      expect(row['log_text'], 'L1\nL2');
    });

    test('log_text is null when logs are off, diagnostics still present', () {
      final row = DiagnosticsFormatter.toDbRow(_report(includeLogs: false));
      expect(row['log_text'], isNull);
      final diag = row['diagnostics']! as Map<String, Object?>;
      expect((diag['log']! as Map)['included'], false);
      expect((diag['device']! as Map)['model'], '2201117TG');
    });

    test('diagnostics json never contains an e-mail field, only the user id', () {
      final json = DiagnosticsFormatter.toJson(_report(contact: 'budi@mail.com'));
      expect(json.toString(), isNot(contains('budi@mail.com')));
      expect(((json['status']! as Map)['user_id']), 'user-uuid-1');
    });

    test('category codes are unique and match the SQL check constraint list', () {
      final codes = ReportCategory.values.map((c) => c.code).toList();
      expect(codes.toSet().length, codes.length);
      expect(codes, <String>[
        'schedule',
        'notification',
        'map',
        'forum',
        'account',
        'other',
      ]);
    });
  });

  group('subject and ids', () {
    test('subject follows the agreed pattern', () {
      expect(
        _report().subject,
        '[Laporan #3F2B8C1E] Notifikasi atau suara tidak berbunyi - Teman Kereta v1.0.17',
      );
    });

    test('shortReportId upper-cases the first 8 hex chars', () {
      expect(shortReportId('abcdef12-0000-0000-0000-000000000000'), 'ABCDEF12');
      expect(shortReportId('abc'), 'ABC');
    });

    test('mailto body is capped', () {
      final long = SupportReport(
        id: 'x' * 36,
        category: ReportCategory.other,
        message: 'y' * 5000,
        snapshot: _snapshot(),
      );
      expect(DiagnosticsFormatter.mailtoBody(long).length, lessThanOrEqualTo(1210));
    });
  });

  group('DiagnosticsCollector', () {
    test('fills the snapshot from the gateway and the log buffer', () async {
      final buffer = LogBuffer()
        ..add(LogLevel.info, 'Trip', 'started')
        ..add(LogLevel.error, 'Alarm', 'tts failed');
      final snapshot = await DiagnosticsCollector(
        _FakeGateway(),
        buffer: buffer,
        clock: () => DateTime(2026, 10, 15, 9),
      ).collect();
      expect(snapshot.appVersion, '1.0.17');
      expect(snapshot.deviceModel, 'Pixel 7');
      expect(snapshot.batteryOptimizationExempt, true);
      expect(snapshot.notificationPermissionGranted, true);
      expect(snapshot.userId, 'uid-1');
      expect(snapshot.logLines, hasLength(2));
      expect(snapshot.lastError, contains('tts failed'));
    });

    test('a failing or hanging probe becomes unknown instead of failing the report', () async {
      final buffer = LogBuffer();
      final snapshot = await DiagnosticsCollector(
        _FakeGateway(failDevice: true, hangConnectivity: true),
        probeTimeout: const Duration(milliseconds: 50),
        buffer: buffer,
      ).collect();
      expect(snapshot.deviceModel, isNull);
      expect(snapshot.connectivity, isNull);
      expect(snapshot.appVersion, '1.0.17');
      expect(
        buffer.entries.where((e) => e.tag == 'Diagnostics'),
        hasLength(2),
      );
    });

    test('includeLogs=false leaves log lines out of the snapshot', () async {
      final buffer = LogBuffer()..add(LogLevel.info, 'T', 'secret-ish');
      final snapshot = await DiagnosticsCollector(
        _FakeGateway(),
        buffer: buffer,
      ).collect(includeLogs: false);
      expect(snapshot.logLines, isEmpty);
    });
  });

  test('describeTimeZone formats abbreviation and offset', () {
    expect(describeTimeZone(DateTime(2026, 1, 1)), matches(RegExp(r'^.+ \(UTC[+-]\d{2}:\d{2}\)$')));
  });
}

class _FakeGateway implements DiagnosticsGateway {
  _FakeGateway({this.failDevice = false, this.hangConnectivity = false});

  final bool failDevice;
  final bool hangConnectivity;

  @override
  Future<AppFacts?> appInfo() async => (version: '1.0.17', build: '18');

  @override
  Future<DeviceFacts?> device() async {
    if (failDevice) {
      throw StateError('no plugin');
    }
    return (
      platform: 'Android',
      osVersion: '14 (SDK 34)',
      manufacturer: 'Google',
      model: 'Pixel 7',
    );
  }

  @override
  Future<String?> connectivity() {
    if (hangConnectivity) {
      return Completer<String?>().future;
    }
    return Future<String?>.value('wifi');
  }

  @override
  Future<bool?> locationServiceEnabled() async => true;

  @override
  Future<String?> locationPermission() async => 'always';

  @override
  Future<Map<String, Object?>> nativePermissions() async => <String, Object?>{
    'backgroundLocation': true,
    'notifications': true,
    'batteryOptimizationIgnored': true,
  };

  @override
  String? userId() => 'uid-1';

  @override
  String? themeMode() => 'dark';

  @override
  String? palette() => 'navyKrl';

  @override
  String? activeTripSummary() => null;
}
