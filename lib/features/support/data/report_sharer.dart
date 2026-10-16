import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/diagnostics/app_log.dart';
import '../support_links.dart';
import 'outgoing_report.dart';

enum ShareOutcome {
  /// The share sheet opened with the .txt attached.
  sharedFile,

  /// Sharing failed; a mailto draft (without attachment) was opened instead.
  openedMailDraft,

  failed,
}

/// Manual fallback when the report cannot be uploaded: hands the .txt to an
/// e-mail app through the system share sheet.
abstract interface class ReportSharer {
  Future<ShareOutcome> shareByEmail(OutgoingReport report);
}

class PlatformReportSharer implements ReportSharer {
  @override
  Future<ShareOutcome> shareByEmail(OutgoingReport report) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'laporan-${report.shortId}.txt'));
      await file.writeAsString(report.text, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'text/plain')],
          subject: report.subject,
          text: 'Kirim ke ${SupportLinks.supportEmail}\n\n${report.mailtoBody}',
        ),
      );
      return ShareOutcome.sharedFile;
    } on Object catch (error) {
      AppLog.w('Report', 'Berbagi berkas gagal: $error');
    }
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: SupportLinks.supportEmail,
        query: _encodeQuery(<String, String>{
          'subject': report.subject,
          'body': report.mailtoBody,
        }),
      );
      final ok = await launchUrl(uri);
      return ok ? ShareOutcome.openedMailDraft : ShareOutcome.failed;
    } on Object catch (error) {
      AppLog.w('Report', 'Draft email gagal dibuka: $error');
      return ShareOutcome.failed;
    }
  }

  /// `Uri(queryParameters:)` encodes spaces as `+`, which mail apps show
  /// literally. mailto needs `%20`.
  static String _encodeQuery(Map<String, String> params) => params.entries
      .map(
        (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');
}

final reportSharerProvider = Provider<ReportSharer>(
  (ref) => PlatformReportSharer(),
);
