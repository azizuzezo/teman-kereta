import 'dart:convert';

import '../../../core/diagnostics/diagnostics_report.dart';

/// A report frozen at submit time: the database row, the full .txt, and the
/// strings the e-mail fallback needs. This is what the offline queue stores
/// and what retries send, so a retry never re-reads the (changed) device state.
class OutgoingReport {
  const OutgoingReport({
    required this.id,
    required this.shortId,
    required this.subject,
    required this.categoryLabel,
    required this.row,
    required this.text,
    required this.mailtoBody,
    required this.createdAt,
  });

  factory OutgoingReport.from(SupportReport report) {
    return OutgoingReport(
      id: report.id,
      shortId: report.shortId,
      subject: report.subject,
      categoryLabel: report.category.label,
      row: DiagnosticsFormatter.toDbRow(report),
      text: DiagnosticsFormatter.toText(report),
      mailtoBody: DiagnosticsFormatter.mailtoBody(report),
      createdAt: report.snapshot.generatedAt,
    );
  }

  factory OutgoingReport.fromJson(Map<String, Object?> json) {
    return OutgoingReport(
      id: json['id']! as String,
      shortId: json['shortId']! as String,
      subject: json['subject']! as String,
      categoryLabel: json['categoryLabel']! as String,
      row: Map<String, Object?>.from(json['row']! as Map),
      text: json['text']! as String,
      mailtoBody: json['mailtoBody']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
    );
  }

  final String id;
  final String shortId;
  final String subject;
  final String categoryLabel;

  /// Payload for `public.app_reports` (see `DiagnosticsFormatter.toDbRow`).
  final Map<String, Object?> row;

  /// Full plain-text report, also the .txt attached in the e-mail fallback.
  final String text;
  final String mailtoBody;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'shortId': shortId,
    'subject': subject,
    'categoryLabel': categoryLabel,
    'row': row,
    'text': text,
    'mailtoBody': mailtoBody,
    'createdAt': createdAt.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());
}
