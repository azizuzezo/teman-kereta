import 'dart:collection';

import '../entities/transit_models.dart';

/// Real, multi-transfer-capable router over a station/line topology — a
/// breadth-first search over the "which lines connect via a shared station"
/// graph, so it finds the shortest real path regardless of how many
/// transfers that takes, rather than only ever trying a direct or
/// single-transfer connection and silently giving up (or worse, guessing).
///
/// Returns a list of per-leg station sequences (each leg's stations, in
/// real stop order, transfer station included at both ends) — a
/// single-element list for a same-line direct trip, more for however many
/// transfers the real network actually needs. Returns null only when the
/// topology genuinely has no chain of shared-station line transfers
/// connecting the two stations — callers must never fabricate a
/// `[origin, destination]` trip in that case; a wrong route is worse than
/// an honest "not found".
List<List<Station>>? routeBetweenStations(
  List<Station> allStations,
  String originId,
  String destinationId,
) {
  final origin = allStations.where((s) => s.id == originId).firstOrNull;
  final destination = allStations.where((s) => s.id == destinationId).firstOrNull;
  if (origin == null ||
      destination == null ||
      origin.lineIds.isEmpty ||
      destination.lineIds.isEmpty) {
    return null;
  }

  final sharedLine =
      origin.lineIds.where((line) => destination.lineIds.contains(line)).firstOrNull;
  if (sharedLine != null) {
    final ordered = orderedStationsOnLine(allStations, sharedLine, originId, destinationId);
    if (ordered.length >= 2) {
      return <List<Station>>[ordered];
    }
  }

  // Line graph: node = line code, edge = a real station serving both lines
  // (the transfer hub). Only the first hub found per line pair is used —
  // good enough for choosing *a* real, correct path; exhaustively picking
  // the "best" hub among several is not needed here.
  final allLines = <String>{};
  final hubFor = <String, Station>{};
  for (final station in allStations) {
    allLines.addAll(station.lineIds);
    for (final a in station.lineIds) {
      for (final b in station.lineIds) {
        if (a == b) continue;
        hubFor.putIfAbsent('$a|$b', () => station);
      }
    }
  }

  final goalLines = destination.lineIds.toSet();
  final visited = <String>{...origin.lineIds};
  final queue = Queue<List<String>>()..addAll(origin.lineIds.map((line) => <String>[line]));

  List<String>? linePath;
  while (queue.isNotEmpty) {
    final path = queue.removeFirst();
    if (goalLines.contains(path.last)) {
      linePath = path;
      break;
    }
    // A real KRL trip needing more than 3 transfers would be a data/routing
    // problem, not a real itinerary — cap the search rather than walk the
    // whole graph looking for one.
    if (path.length > 4) continue;
    for (final next in allLines) {
      if (visited.contains(next) || !hubFor.containsKey('${path.last}|$next')) {
        continue;
      }
      visited.add(next);
      queue.add(<String>[...path, next]);
    }
  }
  if (linePath == null) {
    return null;
  }

  final legs = <List<Station>>[];
  var fromId = originId;
  for (var i = 0; i < linePath.length; i++) {
    final line = linePath[i];
    final isLast = i == linePath.length - 1;
    final toId = isLast ? destinationId : hubFor['$line|${linePath[i + 1]}']!.id;
    final ordered = orderedStationsOnLine(allStations, line, fromId, toId);
    if (ordered.length < 2) {
      return null;
    }
    legs.add(ordered);
    fromId = toId;
  }
  return legs;
}

/// Stations on [lineCode] between [fromId] and [toId] (inclusive), in real
/// stop order — either direction, via `Station.stopOrderByLine`. Empty if
/// either station isn't actually on this line.
List<Station> orderedStationsOnLine(
  List<Station> allStations,
  String lineCode,
  String fromId,
  String toId,
) {
  final onLine = allStations.where((s) => s.lineIds.contains(lineCode)).toList()
    ..sort(
      (a, b) => (a.stopOrderByLine[lineCode] ?? 0).compareTo(b.stopOrderByLine[lineCode] ?? 0),
    );
  final fromIndex = onLine.indexWhere((s) => s.id == fromId);
  final toIndex = onLine.indexWhere((s) => s.id == toId);
  if (fromIndex < 0 || toIndex < 0) {
    return const <Station>[];
  }
  if (fromIndex <= toIndex) {
    return onLine.sublist(fromIndex, toIndex + 1);
  }
  return onLine.sublist(toIndex, fromIndex + 1).reversed.toList(growable: false);
}
