import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'outgoing_report.dart';

/// Reports that could not be delivered yet. They are retried when the report
/// page opens and can be sent by e-mail from the same page.
abstract interface class PendingReportQueue {
  Future<void> add(OutgoingReport report);
  Future<List<OutgoingReport>> all();
  Future<void> remove(String id);
}

/// One JSON file per report in `<documents>/pending_reports/`. Files rather
/// than a Drift table: the payload carries the log text, and a plain file
/// avoids a database schema migration for a rarely used queue.
class FilePendingReportQueue implements PendingReportQueue {
  FilePendingReportQueue({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDirectory;

  /// Oldest reports are dropped beyond this, so the queue cannot grow forever.
  static const int maxQueued = 20;

  Future<Directory> _dir() async {
    final base = await _baseDirectory();
    final dir = Directory(p.join(base.path, 'pending_reports'));
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<void> add(OutgoingReport report) async {
    final dir = await _dir();
    await File(
      p.join(dir.path, '${report.id}.json'),
    ).writeAsString(report.encode(), flush: true);
    final all = await this.all();
    if (all.length > maxQueued) {
      for (final old in all.take(all.length - maxQueued)) {
        await remove(old.id);
      }
    }
  }

  @override
  Future<List<OutgoingReport>> all() async {
    final dir = await _dir();
    final reports = <OutgoingReport>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }
      try {
        final json = jsonDecode(await entity.readAsString());
        reports.add(
          OutgoingReport.fromJson(Map<String, Object?>.from(json as Map)),
        );
      } on Object {
        // Corrupt file: drop it rather than failing every future retry.
        try {
          await entity.delete();
        } on Object {
          // Ignore.
        }
      }
    }
    reports.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return reports;
  }

  @override
  Future<void> remove(String id) async {
    final file = File(p.join((await _dir()).path, '$id.json'));
    if (await file.exists()) {
      await file.delete();
    }
  }
}

final pendingReportQueueProvider = Provider<PendingReportQueue>(
  (ref) => FilePendingReportQueue(),
);
