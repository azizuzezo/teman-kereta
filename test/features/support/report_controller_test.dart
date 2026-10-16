import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/diagnostics/app_log.dart';
import 'package:teman_kereta/core/diagnostics/diagnostics_collector.dart';
import 'package:teman_kereta/core/diagnostics/diagnostics_report.dart';
import 'package:teman_kereta/features/support/data/app_report_repository.dart';
import 'package:teman_kereta/features/support/data/outgoing_report.dart';
import 'package:teman_kereta/features/support/data/pending_report_queue.dart';
import 'package:teman_kereta/features/support/data/report_sharer.dart';
import 'package:teman_kereta/features/support/presentation/report_controller.dart';

class FakeRepository implements AppReportRepository {
  /// Failures consumed one per call; empty means success.
  final List<ReportFailureKind> failures = <ReportFailureKind>[];
  final List<OutgoingReport> sent = <OutgoingReport>[];
  int calls = 0;

  @override
  Future<void> submit(OutgoingReport report) async {
    calls += 1;
    if (failures.isNotEmpty) {
      throw ReportSubmitException(failures.removeAt(0), 'boom');
    }
    sent.add(report);
  }
}

class MemoryQueue implements PendingReportQueue {
  final Map<String, OutgoingReport> items = <String, OutgoingReport>{};
  bool failOnAdd = false;

  @override
  Future<void> add(OutgoingReport report) async {
    if (failOnAdd) {
      throw StateError('disk full');
    }
    items[report.id] = report;
  }

  @override
  Future<List<OutgoingReport>> all() async => items.values.toList();

  @override
  Future<void> remove(String id) async => items.remove(id);
}

class FakeSharer implements ReportSharer {
  final List<OutgoingReport> shared = <OutgoingReport>[];

  @override
  Future<ShareOutcome> shareByEmail(OutgoingReport report) async {
    shared.add(report);
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
  Future<Map<String, Object?>> nativePermissions() async =>
      <String, Object?>{'notifications': true};
  @override
  String? userId() => 'uid-1';
  @override
  String? themeMode() => 'light';
  @override
  String? palette() => 'navyKrl';
  @override
  String? activeTripSummary() => null;
}

const _longEnough = 'Suara pengumuman tidak berbunyi sama sekali di Manggarai.';

void main() {
  late FakeRepository repository;
  late MemoryQueue queue;
  late FakeSharer sharer;
  late List<(String, String)> localCopies;
  late ProviderContainer container;
  var idCounter = 0;

  ReportController controller() =>
      container.read(reportControllerProvider.notifier);
  ReportState state() => container.read(reportControllerProvider);

  void fillValidForm() {
    controller()
      ..setCategory(ReportCategory.notification)
      ..setMessage(_longEnough);
  }

  setUp(() {
    repository = FakeRepository();
    queue = MemoryQueue();
    sharer = FakeSharer();
    localCopies = <(String, String)>[];
    idCounter = 0;
    container = ProviderContainer(
      overrides: [
        appReportRepositoryProvider.overrideWithValue(repository),
        pendingReportQueueProvider.overrideWithValue(queue),
        reportSharerProvider.overrideWithValue(sharer),
        reportAccountEmailProvider.overrideWithValue('akun@mail.com'),
        reportIdGeneratorProvider.overrideWithValue(
          () => 'aaaaaaa${++idCounter}-0000-4000-8000-000000000000',
        ),
        reportLocalCopyProvider.overrideWithValue(
          (category, description) async =>
              localCopies.add((category, description)),
        ),
        diagnosticsCollectorProvider.overrideWithValue(
          DiagnosticsCollector(_Gateway(), buffer: LogBuffer()),
        ),
      ],
    );
    container.listen(reportControllerProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  group('validation', () {
    test('rejects empty form with category and message errors, sends nothing', () async {
      await controller().submit();
      expect(state().phase, ReportPhase.editing);
      expect(state().errors.keys, containsAll(<ReportField>[ReportField.category, ReportField.message]));
      expect(repository.calls, 0);
    });

    test('message shorter than the minimum is rejected, counting trimmed length', () {
      final errors = validateReportForm(
        category: ReportCategory.other,
        message: '   pendek   ',
        includeContactEmail: false,
        contactEmail: '',
      );
      expect(errors[ReportField.message], contains('$kMinReportMessageLength'));
    });

    test('contact e-mail is only validated when the switch is on', () {
      expect(
        validateReportForm(
          category: ReportCategory.other,
          message: _longEnough,
          includeContactEmail: false,
          contactEmail: 'bukan-email',
        ),
        isEmpty,
      );
      expect(
        validateReportForm(
          category: ReportCategory.other,
          message: _longEnough,
          includeContactEmail: true,
          contactEmail: 'bukan-email',
        ).keys,
        <ReportField>[ReportField.email],
      );
    });

    test('contact field is prefilled from the account but not included by default', () {
      expect(state().contactEmail, 'akun@mail.com');
      expect(state().includeContactEmail, isFalse);
      expect(state().includeLogs, isTrue);
    });
  });

  group('submit success', () {
    test('stores once, shows the short reference id, clears the queue', () async {
      fillValidForm();
      await controller().submit();

      expect(state().phase, ReportPhase.sent);
      expect(state().referenceId, 'AAAAAAA1');
      expect(repository.sent, hasLength(1));
      final row = repository.sent.single.row;
      expect(row['category'], 'notification');
      expect(row['contact_email'], isNull);
      expect(row['log_text'], isA<String>());
      expect(queue.items, isEmpty);
      expect(localCopies.single, ('Notifikasi atau suara tidak berbunyi', _longEnough));
    });

    test('contact e-mail travels only when ticked, and logs only when ticked', () async {
      fillValidForm();
      controller()
        ..setIncludeContactEmail(true)
        ..setContactEmail(' budi@mail.com ')
        ..setIncludeLogs(false);
      await controller().submit();

      final row = repository.sent.single.row;
      expect(row['contact_email'], 'budi@mail.com');
      expect(row['log_text'], isNull);
      expect(state().phase, ReportPhase.sent, reason: 'report is allowed without logs');
    });

    test('a successful submit also flushes older queued reports', () async {
      final old = OutgoingReport(
        id: 'old-1',
        shortId: 'OLD1',
        subject: 's',
        categoryLabel: 'c',
        row: const <String, Object?>{'id': 'old-1'},
        text: 't',
        mailtoBody: 'b',
        createdAt: DateTime(2026, 10, 1),
      );
      await queue.add(old);
      fillValidForm();
      await controller().submit();
      await Future<void>.delayed(Duration.zero);

      expect(repository.sent.map((r) => r.id), contains('old-1'));
      expect(queue.items, isEmpty);
    });
  });

  group('offline fallback', () {
    test('network failure queues the report locally and keeps the form data', () async {
      repository.failures.add(ReportFailureKind.offline);
      fillValidForm();
      await controller().submit();

      expect(state().phase, ReportPhase.queued);
      expect(state().failureMessage, contains('koneksi'));
      expect(state().referenceId, 'AAAAAAA1');
      expect(queue.items.keys, <String>['aaaaaaa1-0000-4000-8000-000000000000']);
      expect(state().pendingCount, 1);
      expect(state().message, _longEnough);
    });

    test('server rejection also queues, with a different message', () async {
      repository.failures.add(ReportFailureKind.server);
      fillValidForm();
      await controller().submit();
      expect(state().phase, ReportPhase.queued);
      expect(state().failureMessage, contains('Server'));
    });

    test('retry re-sends the SAME report id and clears the queue on success', () async {
      repository.failures.add(ReportFailureKind.offline);
      fillValidForm();
      await controller().submit();
      final firstId = state().outgoing!.id;

      await controller().retry();

      expect(state().phase, ReportPhase.sent);
      expect(repository.sent.single.id, firstId);
      expect(queue.items, isEmpty);
      expect(idCounter, 1, reason: 'retry must not generate a new report id');
    });

    test('retry that fails again stays queued without duplicating', () async {
      repository.failures
        ..add(ReportFailureKind.offline)
        ..add(ReportFailureKind.offline);
      fillValidForm();
      await controller().submit();
      await controller().retry();
      expect(state().phase, ReportPhase.queued);
      expect(queue.items, hasLength(1));
    });

    test('if even the local queue fails, phase is failed and e-mail still works', () async {
      repository.failures.add(ReportFailureKind.offline);
      queue.failOnAdd = true;
      fillValidForm();
      await controller().submit();

      expect(state().phase, ReportPhase.failed);
      final outcome = await controller().shareByEmail();
      expect(outcome, ShareOutcome.sharedFile);
      expect(sharer.shared.single.subject, startsWith('[Laporan #AAAAAAA1]'));
      expect(sharer.shared.single.text, startsWith('=== TEMAN KERETA LAPORAN ==='));
    });

    test('retryPending delivers queued reports when the page reopens', () async {
      final a = _queued('a');
      final b = _queued('b');
      await queue.add(a);
      await queue.add(b);

      await controller().retryPending();

      expect(repository.sent.map((r) => r.id), <String>['a', 'b']);
      expect(queue.items, isEmpty);
      expect(state().lastFlushedCount, 2);
      expect(state().pendingCount, 0);
    });

    test('retryPending stops at the first failure and keeps the rest queued', () async {
      await queue.add(_queued('a'));
      await queue.add(_queued('b'));
      repository.failures.add(ReportFailureKind.offline);

      await controller().retryPending();

      expect(repository.calls, 1);
      expect(queue.items.keys.toSet(), <String>{'a', 'b'});
      expect(state().pendingCount, 2);
      expect(state().lastFlushedCount, 0);
    });
  });

  group('misc', () {
    test('submit while already submitting is ignored', () async {
      fillValidForm();
      final first = controller().submit();
      final second = controller().submit();
      await Future.wait<void>(<Future<void>>[first, second]);
      expect(repository.calls, 1);
    });

    test('shareByEmail without a report fails gracefully', () async {
      expect(await controller().shareByEmail(), ShareOutcome.failed);
    });

    test('preview shows the exact formatted report incl. log toggle state', () async {
      fillValidForm();
      await controller().loadPreview();
      expect(state().previewText, startsWith('=== TEMAN KERETA LAPORAN ==='));
      controller().setIncludeLogs(false);
      expect(state().previewText, isNull, reason: 'stale preview is cleared');
      await controller().loadPreview();
      expect(state().previewText, contains('(tidak disertakan)'));
    });

    test('reset returns to an empty editing form', () async {
      fillValidForm();
      await controller().submit();
      controller().reset();
      expect(state().phase, ReportPhase.editing);
      expect(state().message, isEmpty);
      expect(state().category, isNull);
    });
  });
}

OutgoingReport _queued(String id) => OutgoingReport(
  id: id,
  shortId: id.toUpperCase(),
  subject: 's',
  categoryLabel: 'c',
  row: <String, Object?>{'id': id},
  text: 't',
  mailtoBody: 'b',
  createdAt: DateTime(2026, 10, 1).add(Duration(minutes: id.codeUnitAt(0))),
);
