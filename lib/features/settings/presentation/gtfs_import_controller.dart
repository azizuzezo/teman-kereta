import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../data/providers/gtfs_static_importer.dart';

class GtfsImportStatus {
  const GtfsImportStatus({required this.stopCount, this.lastImportSummary});

  final int stopCount;
  final GtfsImportSummary? lastImportSummary;

  bool get hasImportedData => stopCount > 0;
}

/// Drives the "Impor jadwal GTFS" settings page — the missing UI piece that
/// made `GtfsStaticImporter`/`GtfsStaticScheduleProvider` reachable only
/// programmatically before this. Picking a file and cancelling the OS
/// picker are both normal outcomes, not errors; only a real read/parse
/// failure surfaces as [AsyncValue.error].
class GtfsImportController extends AsyncNotifier<GtfsImportStatus> {
  @override
  Future<GtfsImportStatus> build() async {
    final database = ref.watch(appDatabaseProvider);
    return GtfsImportStatus(stopCount: await database.gtfsStopCount());
  }

  Future<void> pickAndImportZip() async {
    final previous = state;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: <String>['zip'],
      );
      if (picked == null) {
        return previous.value ?? await build();
      }

      final bytes = await picked.readAsBytes();
      final importer = GtfsStaticImporter(
        database: ref.read(appDatabaseProvider),
      );
      final summary = await importer.importZipBytes(bytes);
      return GtfsImportStatus(
        stopCount: summary.stopCount,
        lastImportSummary: summary,
      );
    });
  }
}

final gtfsImportControllerProvider =
    AsyncNotifierProvider<GtfsImportController, GtfsImportStatus>(
      GtfsImportController.new,
    );
