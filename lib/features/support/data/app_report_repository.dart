import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config/app_environment.dart';
import '../../../core/diagnostics/app_log.dart';
import 'outgoing_report.dart';

enum ReportFailureKind {
  /// No network, timeout, or Supabase disabled: queue locally and retry.
  offline,

  /// The server answered with an error (rate limit, constraint, outage).
  server,
}

class ReportSubmitException implements Exception {
  const ReportSubmitException(this.kind, this.message);

  final ReportFailureKind kind;
  final String message;

  @override
  String toString() => 'ReportSubmitException(${kind.name}): $message';
}

abstract interface class AppReportRepository {
  /// Inserts the report. Completes normally when the row exists afterwards
  /// (including "already inserted by an earlier attempt").
  Future<void> submit(OutgoingReport report);
}

/// Inserts straight into `public.app_reports` with the anon/user key. RLS only
/// allows INSERT, so the call deliberately does not ask for the row back
/// (`.select()` would need a SELECT policy). The client-generated uuid is the
/// reference id shown to the user.
class SupabaseAppReportRepository implements AppReportRepository {
  SupabaseAppReportRepository({this.timeout = const Duration(seconds: 25)});

  final Duration timeout;

  @override
  Future<void> submit(OutgoingReport report) async {
    if (!AppEnvironment.supabaseEnabled) {
      throw const ReportSubmitException(
        ReportFailureKind.offline,
        'Supabase tidak aktif di build ini.',
      );
    }
    try {
      await Supabase.instance.client
          .from('app_reports')
          .insert(report.row)
          .timeout(timeout);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        // Same id sent before and the response was lost: row exists.
        AppLog.i('Report', 'Laporan ${report.shortId} sudah ada di server.');
        return;
      }
      AppLog.w(
        'Report',
        'Server menolak ${report.shortId}: ${error.code} ${error.message}',
      );
      throw ReportSubmitException(ReportFailureKind.server, error.message);
    } on TimeoutException {
      throw const ReportSubmitException(
        ReportFailureKind.offline,
        'Server tidak menjawab tepat waktu.',
      );
    } on SocketException catch (error) {
      throw ReportSubmitException(ReportFailureKind.offline, error.message);
    } on Object catch (error) {
      // supabase-dart wraps transport failures in ClientException/AuthException.
      final text = error.toString();
      final offline =
          text.contains('SocketException') ||
          text.contains('ClientException') ||
          text.contains('Failed host lookup') ||
          text.contains('Connection');
      throw ReportSubmitException(
        offline ? ReportFailureKind.offline : ReportFailureKind.server,
        text,
      );
    }
  }
}

final appReportRepositoryProvider = Provider<AppReportRepository>(
  (ref) => SupabaseAppReportRepository(),
);
