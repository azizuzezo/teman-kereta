import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/config/app_environment.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/diagnostics/app_log.dart';
import '../../../core/diagnostics/diagnostics_collector.dart';
import '../../../core/diagnostics/diagnostics_report.dart';
import '../data/app_report_repository.dart';
import '../data/outgoing_report.dart';
import '../data/pending_report_queue.dart';
import '../data/report_sharer.dart';

const int kMinReportMessageLength = 15;
const int kMaxReportMessageLength = 2000;

enum ReportPhase {
  /// Filling in the form.
  editing,
  submitting,

  /// Stored on the server; [ReportState.referenceId] is set.
  sent,

  /// Upload failed, report saved on the device and waiting for a retry.
  queued,

  /// Upload failed and the local save failed too; only e-mail is left.
  failed,
}

enum ReportField { category, message, email }

@immutable
class ReportState {
  const ReportState({
    this.category,
    this.message = '',
    this.contactEmail = '',
    this.includeContactEmail = false,
    this.includeLogs = true,
    this.phase = ReportPhase.editing,
    this.errors = const <ReportField, String>{},
    this.referenceId,
    this.failureMessage,
    this.outgoing,
    this.pendingCount = 0,
    this.lastFlushedCount = 0,
    this.previewText,
    this.previewLoading = false,
  });

  final ReportCategory? category;
  final String message;
  final String contactEmail;
  final bool includeContactEmail;
  final bool includeLogs;
  final ReportPhase phase;
  final Map<ReportField, String> errors;
  final String? referenceId;
  final String? failureMessage;

  /// The frozen report of the last submit attempt; retry and e-mail reuse it.
  final OutgoingReport? outgoing;

  /// Queued reports from earlier sessions still waiting to be sent.
  final int pendingCount;

  /// How many queued reports the last automatic retry delivered.
  final int lastFlushedCount;
  final String? previewText;
  final bool previewLoading;

  ReportState copyWith({
    ReportCategory? category,
    String? message,
    String? contactEmail,
    bool? includeContactEmail,
    bool? includeLogs,
    ReportPhase? phase,
    Map<ReportField, String>? errors,
    String? referenceId,
    String? failureMessage,
    OutgoingReport? outgoing,
    int? pendingCount,
    int? lastFlushedCount,
    String? previewText,
    bool? previewLoading,
    bool clearPreview = false,
    bool clearFailure = false,
  }) {
    return ReportState(
      category: category ?? this.category,
      message: message ?? this.message,
      contactEmail: contactEmail ?? this.contactEmail,
      includeContactEmail: includeContactEmail ?? this.includeContactEmail,
      includeLogs: includeLogs ?? this.includeLogs,
      phase: phase ?? this.phase,
      errors: errors ?? this.errors,
      referenceId: referenceId ?? this.referenceId,
      failureMessage: clearFailure
          ? null
          : (failureMessage ?? this.failureMessage),
      outgoing: outgoing ?? this.outgoing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastFlushedCount: lastFlushedCount ?? this.lastFlushedCount,
      previewText: clearPreview ? null : (previewText ?? this.previewText),
      previewLoading: previewLoading ?? this.previewLoading,
    );
  }
}

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Pure validation, unit-tested. Empty map means the form is valid.
Map<ReportField, String> validateReportForm({
  required ReportCategory? category,
  required String message,
  required bool includeContactEmail,
  required String contactEmail,
}) {
  final errors = <ReportField, String>{};
  if (category == null) {
    errors[ReportField.category] = 'Pilih jenis masalahnya dulu.';
  }
  final length = message.trim().length;
  if (length < kMinReportMessageLength) {
    errors[ReportField.message] =
        'Ceritakan sedikitnya $kMinReportMessageLength karakter supaya kami bisa memahaminya (sekarang $length).';
  } else if (length > kMaxReportMessageLength) {
    errors[ReportField.message] =
        'Terlalu panjang. Maksimal $kMaxReportMessageLength karakter.';
  }
  if (includeContactEmail && !_emailPattern.hasMatch(contactEmail.trim())) {
    errors[ReportField.email] =
        'Alamat email belum benar. Contoh: nama@email.com';
  }
  return errors;
}

/// The signed-in account's e-mail, used only to prefill the optional contact
/// field. Overridable in tests.
final reportAccountEmailProvider = Provider<String?>((ref) {
  if (!AppEnvironment.supabaseEnabled) {
    return null;
  }
  try {
    return Supabase.instance.client.auth.currentUser?.email;
  } on Object {
    return null;
  }
});

/// Writes the existing on-device copy of each submitted report (the local
/// Drift table that predates server delivery).
final reportLocalCopyProvider =
    Provider<Future<void> Function(String category, String description)>((ref) {
      return (category, description) => ref
          .read(appDatabaseProvider)
          .saveUserReport(
            UserReportsCompanion.insert(
              category: category,
              description: description,
              createdAt: DateTime.now(),
            ),
          );
    });

final reportIdGeneratorProvider = Provider<String Function()>(
  (ref) =>
      () => const Uuid().v4(),
);

class ReportController extends Notifier<ReportState> {
  @override
  ReportState build() {
    final email = ref.read(reportAccountEmailProvider);
    return ReportState(contactEmail: email ?? '');
  }

  void setCategory(ReportCategory category) {
    state = state.copyWith(
      category: category,
      errors: _without(ReportField.category),
      clearPreview: true,
    );
  }

  void setMessage(String value) {
    state = state.copyWith(
      message: value,
      errors: state.errors.containsKey(ReportField.message)
          ? _without(ReportField.message)
          : null,
      clearPreview: true,
    );
  }

  void setContactEmail(String value) {
    state = state.copyWith(
      contactEmail: value,
      errors: state.errors.containsKey(ReportField.email)
          ? _without(ReportField.email)
          : null,
    );
  }

  void setIncludeContactEmail(bool value) {
    state = state.copyWith(
      includeContactEmail: value,
      errors: value ? null : _without(ReportField.email),
      clearPreview: true,
    );
  }

  void setIncludeLogs(bool value) {
    state = state.copyWith(includeLogs: value, clearPreview: true);
  }

  Map<ReportField, String> _without(ReportField field) =>
      Map<ReportField, String>.of(state.errors)..remove(field);

  /// Builds the exact text that would be sent, for the expandable preview.
  Future<void> loadPreview() async {
    if (state.previewLoading) {
      return;
    }
    state = state.copyWith(previewLoading: true);
    try {
      final report = await _buildReport(id: 'pratinjau-laporan');
      state = state.copyWith(
        previewText: DiagnosticsFormatter.toText(report),
        previewLoading: false,
      );
    } on Object catch (error) {
      AppLog.w('Report', 'Pratinjau gagal: $error');
      state = state.copyWith(
        previewText: 'Pratinjau tidak bisa dimuat. Laporan tetap bisa dikirim.',
        previewLoading: false,
      );
    }
  }

  Future<SupportReport> _buildReport({required String id}) async {
    final snapshot = await ref
        .read(diagnosticsCollectorProvider)
        .collect(includeLogs: state.includeLogs);
    return SupportReport(
      id: id,
      category: state.category ?? ReportCategory.other,
      message: state.message,
      contactEmail: state.includeContactEmail
          ? state.contactEmail.trim()
          : null,
      includeLogs: state.includeLogs,
      snapshot: snapshot,
    );
  }

  /// Validates, collects diagnostics, uploads. On failure the report is saved
  /// to the offline queue and the state becomes [ReportPhase.queued].
  Future<void> submit() async {
    if (state.phase == ReportPhase.submitting) {
      return;
    }
    final errors = validateReportForm(
      category: state.category,
      message: state.message,
      includeContactEmail: state.includeContactEmail,
      contactEmail: state.contactEmail,
    );
    if (errors.isNotEmpty) {
      state = state.copyWith(errors: errors);
      return;
    }
    state = state.copyWith(
      phase: ReportPhase.submitting,
      errors: const <ReportField, String>{},
      clearFailure: true,
    );

    OutgoingReport outgoing;
    try {
      final report = await _buildReport(
        id: ref.read(reportIdGeneratorProvider)(),
      );
      outgoing = OutgoingReport.from(report);
    } on Object catch (error, stack) {
      AppLog.e('Report', 'Gagal menyusun laporan', error: error, stack: stack);
      state = state.copyWith(
        phase: ReportPhase.editing,
        failureMessage: 'Laporan belum bisa disusun. Coba lagi sebentar lagi.',
      );
      return;
    }

    unawaited(_saveLocalCopy());
    state = state.copyWith(outgoing: outgoing);
    await _upload(outgoing);
  }

  /// Re-sends the report of the last failed attempt (same id, so a lost
  /// response can never create a duplicate).
  Future<void> retry() async {
    final outgoing = state.outgoing;
    if (outgoing == null || state.phase == ReportPhase.submitting) {
      return;
    }
    state = state.copyWith(phase: ReportPhase.submitting, clearFailure: true);
    await _upload(outgoing);
  }

  Future<void> _upload(OutgoingReport outgoing) async {
    final repository = ref.read(appReportRepositoryProvider);
    final queue = ref.read(pendingReportQueueProvider);
    try {
      await repository.submit(outgoing);
      AppLog.i('Report', 'Laporan ${outgoing.shortId} terkirim.');
      try {
        await queue.remove(outgoing.id);
      } on Object {
        // Not queued, or queue unreadable: nothing to clean up.
      }
      state = state.copyWith(
        phase: ReportPhase.sent,
        referenceId: outgoing.shortId,
        clearFailure: true,
      );
      unawaited(retryPending());
    } on ReportSubmitException catch (error) {
      AppLog.w('Report', 'Upload ${outgoing.shortId} gagal: $error');
      await _fallBackToQueue(outgoing, error);
    } on Object catch (error, stack) {
      AppLog.e(
        'Report',
        'Upload tak terduga gagal',
        error: error,
        stack: stack,
      );
      await _fallBackToQueue(
        outgoing,
        ReportSubmitException(ReportFailureKind.server, error.toString()),
      );
    }
  }

  Future<void> _fallBackToQueue(
    OutgoingReport outgoing,
    ReportSubmitException error,
  ) async {
    final reason = error.kind == ReportFailureKind.offline
        ? 'Tidak ada koneksi ke server.'
        : 'Server belum bisa menerima laporan sekarang.';
    try {
      await ref.read(pendingReportQueueProvider).add(outgoing);
      state = state.copyWith(
        phase: ReportPhase.queued,
        referenceId: outgoing.shortId,
        failureMessage: reason,
        pendingCount: (await ref.read(pendingReportQueueProvider).all()).length,
      );
    } on Object catch (queueError) {
      AppLog.e('Report', 'Antrean lokal gagal: $queueError');
      state = state.copyWith(
        phase: ReportPhase.failed,
        referenceId: outgoing.shortId,
        failureMessage: reason,
      );
    }
  }

  /// True unless the server answered this report with an error of its own.
  /// Unknown errors count as connectivity trouble: the safe reading is to stop.
  static bool _isConnectivityError(Object error) =>
      !(error is ReportSubmitException &&
          error.kind == ReportFailureKind.server);

  /// Sends queued reports from earlier attempts. Called when the report page
  /// opens and after any successful submit. Never throws.
  Future<void> retryPending() async {
    final queue = ref.read(pendingReportQueueProvider);
    final repository = ref.read(appReportRepositoryProvider);
    try {
      final queued = await queue.all();
      if (queued.isEmpty) {
        state = state.copyWith(pendingCount: 0);
        return;
      }
      var sent = 0;
      for (final report in queued) {
        try {
          await repository.submit(report);
          await queue.remove(report.id);
          sent += 1;
        } on Object catch (error) {
          // A connection problem hits every queued report equally, so stop
          // hammering. A report the server rejected on its own merits (bad
          // payload, rate limit) must not block the ones behind it.
          if (_isConnectivityError(error)) {
            break;
          }
          AppLog.w('Report', 'Laporan tertunda ditolak server: $error');
        }
      }
      if (sent > 0) {
        AppLog.i('Report', '$sent laporan tertunda terkirim.');
      }
      state = state.copyWith(
        pendingCount: queued.length - sent,
        lastFlushedCount: sent,
      );
    } on Object catch (error) {
      AppLog.w('Report', 'Cek antrean gagal: $error');
    }
  }

  Future<ShareOutcome> shareByEmail() async {
    final outgoing = state.outgoing;
    if (outgoing == null) {
      return ShareOutcome.failed;
    }
    return ref.read(reportSharerProvider).shareByEmail(outgoing);
  }

  Future<void> _saveLocalCopy() async {
    try {
      final category = state.category;
      if (category == null) {
        return;
      }
      await ref.read(reportLocalCopyProvider)(
        category.label,
        state.message.trim(),
      );
    } on Object catch (error) {
      AppLog.w('Report', 'Salinan lokal gagal: $error');
    }
  }

  /// Back to an empty form (used by "Kirim laporan lain").
  void reset() {
    final email = ref.read(reportAccountEmailProvider);
    state = ReportState(
      contactEmail: email ?? '',
      pendingCount: state.pendingCount,
    );
  }
}

final reportControllerProvider =
    NotifierProvider.autoDispose<ReportController, ReportState>(
      ReportController.new,
    );
