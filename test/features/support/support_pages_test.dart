import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/core/diagnostics/app_log.dart';
import 'package:teman_kereta/core/diagnostics/diagnostics_collector.dart';
import 'package:teman_kereta/core/updates/update_checker.dart';
import 'package:teman_kereta/features/support/data/app_report_repository.dart';
import 'package:teman_kereta/features/support/data/outgoing_report.dart';
import 'package:teman_kereta/features/support/data/pending_report_queue.dart';
import 'package:teman_kereta/features/support/data/report_sharer.dart';
import 'package:teman_kereta/features/support/presentation/app_update_page.dart';
import 'package:teman_kereta/features/support/presentation/report_controller.dart';
import 'package:teman_kereta/features/support/presentation/support_pages.dart';

class _NoopUpdateChecker extends UpdateCheckerController {
  @override
  PendingAppUpdate? build() => null;
}

class _Repo implements AppReportRepository {
  ReportFailureKind? failWith;
  final List<OutgoingReport> sent = <OutgoingReport>[];
  @override
  Future<void> submit(OutgoingReport report) async {
    if (failWith != null) {
      throw ReportSubmitException(failWith!, 'x');
    }
    sent.add(report);
  }
}

class _Queue implements PendingReportQueue {
  final Map<String, OutgoingReport> items = <String, OutgoingReport>{};
  @override
  Future<void> add(OutgoingReport report) async => items[report.id] = report;
  @override
  Future<List<OutgoingReport>> all() async => items.values.toList();
  @override
  Future<void> remove(String id) async => items.remove(id);
}

class _Sharer implements ReportSharer {
  int calls = 0;
  @override
  Future<ShareOutcome> shareByEmail(OutgoingReport report) async {
    calls += 1;
    return ShareOutcome.sharedFile;
  }
}

class _Gateway implements DiagnosticsGateway {
  @override
  Future<AppFacts?> appInfo() async => (version: '1.0.17', build: '18');
  @override
  Future<DeviceFacts?> device() async =>
      (platform: 'Android', osVersion: '14', manufacturer: 'Google', model: 'Pixel');
  @override
  Future<String?> connectivity() async => 'wifi';
  @override
  Future<bool?> locationServiceEnabled() async => true;
  @override
  Future<String?> locationPermission() async => 'always';
  @override
  Future<Map<String, Object?>> nativePermissions() async => <String, Object?>{};
  @override
  String? userId() => null;
  @override
  String? themeMode() => 'light';
  @override
  String? palette() => 'navyKrl';
  @override
  String? activeTripSummary() => null;
}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  _Repo? repo,
  _Sharer? sharer,
}) async {
  tester.view.physicalSize = const Size(360, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        updateCheckerControllerProvider.overrideWith(_NoopUpdateChecker.new),
        packageInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'Teman Kereta',
            packageName: 'id.temankereta.teman_kereta',
            version: '1.0.17',
            buildNumber: '18',
          ),
        ),
        latestReleaseFetcherProvider.overrideWithValue(
          () async => <String, dynamic>{
            'version_code': 18,
            'version_name': '1.0.17',
            'apk_url': 'https://example.com/a.apk',
            'changelog': null,
            'min_supported_version_code': null,
          },
        ),
        appReportRepositoryProvider.overrideWithValue(repo ?? _Repo()),
        pendingReportQueueProvider.overrideWithValue(_Queue()),
        reportSharerProvider.overrideWithValue(sharer ?? _Sharer()),
        reportAccountEmailProvider.overrideWithValue('akun@mail.com'),
        reportIdGeneratorProvider.overrideWithValue(
          () => 'abcd1234-0000-4000-8000-000000000000',
        ),
        reportLocalCopyProvider.overrideWithValue((_, _) async {}),
        diagnosticsCollectorProvider.overrideWithValue(
          DiagnosticsCollector(_Gateway(), buffer: LogBuffer()),
        ),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in <double>[1.0, 1.3]) {
      final label = '${brightness.name} x$scale';

      testWidgets('Help renders without overflow ($label)', (tester) async {
        await _pump(tester, const HelpPage(), brightness: brightness, textScale: scale);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Menghapus akun'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await _tapText(tester, 'Menghapus akun');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Profil, bagian Akun'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Laporkan masalah'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('Privacy renders without overflow ($label)', (tester) async {
        await _pump(tester, const PrivacyPage(), brightness: brightness, textScale: scale);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Baca kebijakan lengkap'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Halaman hapus akun'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('About renders without overflow ($label)', (tester) async {
        await _pump(tester, const AppUpdatePage(), brightness: brightness, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('Versi 1.0.17 (18)'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Cek pembaruan'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Cek pembaruan'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Lisensi pustaka'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('Report form renders without overflow ($label)', (tester) async {
        await _pump(tester, const ReportPage(), brightness: brightness, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('Kirim laporan'), findsOneWidget);
      });
    }
  }

  testWidgets('About: Cek pembaruan shows the up-to-date result', (tester) async {
    await _pump(tester, const AppUpdatePage());
    await _tapText(tester, 'Cek pembaruan');
    await tester.pumpAndSettle();
    expect(find.text('Kamu memakai versi terbaru'), findsOneWidget);
  });

  testWidgets('Report: validation, then success screen with reference id', (tester) async {
    final repo = _Repo();
    await _pump(tester, const ReportPage(), repo: repo);

    await _tapText(tester, 'Kirim laporan');
    await tester.pump();
    expect(find.text('Pilih jenis masalahnya dulu.'), findsOneWidget);
    expect(repo.sent, isEmpty);

    await _tapText(tester, 'Jadwal salah');
    await tester.enterText(
      find.byType(TextField).first,
      'Jadwal Bogor 07.10 tidak ada di stasiun Manggarai.',
    );
    await tester.pump();
    await _tapText(tester, 'Kirim laporan');
    await tester.pumpAndSettle();

    expect(find.text('Laporan terkirim'), findsOneWidget);
    expect(find.text('#ABCD1234'), findsOneWidget);
    expect(repo.sent.single.row['category'], 'schedule');
  });

  testWidgets('Report: logs switch explains consequences when turned off', (tester) async {
    await _pump(tester, const ReportPage());
    expect(
      find.text('Membantu kami menemukan penyebab masalah. Tidak berisi kata sandi.'),
      findsOneWidget,
    );
    final switches = find.byType(Switch);
    await tester.ensureVisible(switches.last);
    await tester.pump();
    await tester.tap(switches.last);
    await tester.pump();
    expect(find.textContaining('lebih sulit mencari penyebabnya'), findsOneWidget);
  });

  testWidgets('Report: expanding the preview shows the structured report', (tester) async {
    await _pump(tester, const ReportPage());
    await _tapText(tester, 'Log yang ikut terkirim');
    await tester.pumpAndSettle();
    expect(find.textContaining('=== TEMAN KERETA LAPORAN ==='), findsOneWidget);
    expect(find.textContaining('[Perangkat]'), findsOneWidget);
  });

  testWidgets('Report: offline shows retry and e-mail fallback, e-mail is wired', (tester) async {
    final repo = _Repo()..failWith = ReportFailureKind.offline;
    final sharer = _Sharer();
    await _pump(tester, const ReportPage(), repo: repo, sharer: sharer);

    await _tapText(tester, 'Peta atau posisi kereta');
    await tester.enterText(
      find.byType(TextField).first,
      'Posisi kereta di peta loncat-loncat terus.',
    );
    await tester.pump();
    await _tapText(tester, 'Kirim laporan');
    await tester.pumpAndSettle();

    expect(find.text('Laporan belum terkirim'), findsOneWidget);
    expect(find.text('Coba kirim lagi'), findsOneWidget);

    await _tapText(tester, 'Kirim lewat email');
    await tester.pumpAndSettle();
    expect(sharer.calls, 1);

    repo.failWith = null;
    await _tapText(tester, 'Coba kirim lagi');
    await tester.pumpAndSettle();
    expect(find.text('Laporan terkirim'), findsOneWidget);
  });
}
