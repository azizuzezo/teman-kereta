import 'dart:collection';

import '../entities/transit_models.dart';

/// One way to ride from A to B: the per-leg station sequences (transfer
/// station at both ends of a transfer), plus the station the route is named
/// after when the same pair has more than one real way round (the Cikarang
/// loop: "via Manggarai" or "via Pasar Senen").
class RouteOption {
  const RouteOption({required this.legs, this.viaName});

  final List<List<Station>> legs;
  final String? viaName;

  int get transfers => legs.length - 1;

  int get hops {
    var total = 0;
    for (final leg in legs) {
      total += leg.length - 1;
    }
    return total;
  }

  /// Rough "cost" used only to order and prune alternatives: stops travelled
  /// plus a transfer penalty worth about four stops of riding.
  int get score => hops + transfers * 4;
}

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
  final options = routeOptionsBetweenStations(
    allStations,
    originId,
    destinationId,
  );
  return options.isEmpty ? null : options.first.legs;
}

/// Every sensible real route from [originId] to [destinationId], best first.
///
/// Usually one. More than one when the trip runs over the Cikarang loop and
/// both ways round are reasonable — e.g. Bekasi → Kemayoran can go via Pasar
/// Senen (direct) or via Manggarai (change at Kampung Bandan), and Angke →
/// Jatinegara via Manggarai or via Pasar Senen. A way round that is far longer
/// than the best one (Angke → Kemayoran the long way) is left out.
List<RouteOption> routeOptionsBetweenStations(
  List<Station> allStations,
  String originId,
  String destinationId,
) {
  final origin = allStations.where((s) => s.id == originId).firstOrNull;
  final destination = allStations
      .where((s) => s.id == destinationId)
      .firstOrNull;
  if (origin == null ||
      destination == null ||
      origin.lineIds.isEmpty ||
      destination.lineIds.isEmpty) {
    return const <RouteOption>[];
  }

  final shared = origin.lineIds
      .where((line) => destination.lineIds.contains(line))
      .toList(growable: false);
  // A shared ordinary line is a real direct train; prefer it over the loop
  // (Manggarai and Jatinegara are on both the Bogor and the Cikarang lines).
  final sharedLine =
      shared.where((line) => line != cikarangLoopLine).firstOrNull ??
      shared.firstOrNull;
  if (sharedLine != null) {
    final options = _pruned(
      _segmentOptions(allStations, sharedLine, originId, destinationId),
    );
    if (options.isNotEmpty) {
      return options;
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
  final queue = Queue<List<String>>()
    ..addAll(origin.lineIds.map((line) => <String>[line]));

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
    return const <RouteOption>[];
  }

  // Each line of the path becomes one segment; a loop segment can have two
  // ways round. The best route takes every segment's best way; one
  // alternative swaps in the other way round for the first loop segment.
  final segments = <List<RouteOption>>[];
  var fromId = originId;
  for (var i = 0; i < linePath.length; i++) {
    final line = linePath[i];
    final isLast = i == linePath.length - 1;
    final toId = isLast
        ? destinationId
        : hubFor['$line|${linePath[i + 1]}']!.id;
    final options = _segmentOptions(allStations, line, fromId, toId);
    if (options.isEmpty) {
      return const <RouteOption>[];
    }
    segments.add(options);
    fromId = toId;
  }

  RouteOption join(List<RouteOption> parts) {
    final legs = <List<Station>>[for (final p in parts) ...p.legs];
    final via = parts.map((p) => p.viaName).whereType<String>().firstOrNull;
    return RouteOption(legs: legs, viaName: via);
  }

  final best = <RouteOption>[for (final s in segments) s.first];
  final results = <RouteOption>[join(best)];
  final loopIndex = segments.indexWhere((s) => s.length > 1);
  if (loopIndex >= 0) {
    final alternative = List<RouteOption>.of(best);
    alternative[loopIndex] = segments[loopIndex][1];
    results.add(join(alternative));
  }
  return _pruned(results);
}

/// Sorted best first; drops a way round that is much worse than the best.
List<RouteOption> _pruned(List<RouteOption> options) {
  if (options.length < 2) return options;
  final sorted = List<RouteOption>.of(options)
    ..sort((a, b) => a.score.compareTo(b.score));
  final best = sorted.first.score;
  return <RouteOption>[
    sorted.first,
    for (final option in sorted.skip(1))
      if (option.score <= best * 1.7 + 4) option,
  ];
}

/// The ways to ride [lineCode] from [fromId] to [toId]: one for an ordinary
/// line, up to two for the Cikarang loop.
List<RouteOption> _segmentOptions(
  List<Station> allStations,
  String lineCode,
  String fromId,
  String toId,
) {
  if (lineCode == cikarangLoopLine) {
    final loop = cikarangLoopOptions(allStations, fromId, toId);
    if (loop != null) {
      return loop;
    }
  }
  final ordered = orderedStationsOnLine(allStations, lineCode, fromId, toId);
  if (ordered.length < 2) {
    return const <RouteOption>[];
  }
  return <RouteOption>[
    RouteOption(legs: <List<Station>>[ordered]),
  ];
}

/// Line code of the Cikarang loop.
const cikarangLoopLine = 'CIKARANG';

/// Where the Cikarang branch meets the loop.
const _loopJunction = 'JNG';

/// Where every loop train ends, from either direction (Kampung Bandan): riding
/// on past it means changing trains there.
const _loopSeam = 'KPB';

/// Stations a loop route is named after, in priority order.
const _loopViaCodes = <String>['MRI', 'PSE', 'THB', 'JNG', 'KPB'];

/// The Cikarang loop as it really runs. `station_lines.stop_order` stores it
/// as one straight line (Cikarang ... Jatinegara, Matraman, Manggarai ...
/// Kampung Bandan ... Pasar Senen ... Pondok Jati), but Pondok Jati is next
/// to Jatinegara again: the part from Jatinegara on is a ring, and the part
/// before it (Cikarang ... Klender) is a branch into it.
///
/// Real trains (from the published timetable) run the branch into the ring
/// in either direction and end at Kampung Bandan, so:
/// * a ride that passes Kampung Bandan changes trains there, and
/// * a ride along the ring through Jatinegara (Matraman <-> Pondok Jati)
///   changes trains at Jatinegara.
///
/// Returns both ways round (best first, much longer ones pruned) when both
/// stations are on the loop, or null when the data does not have the loop's
/// shape (so callers fall back to the straight stop order).
List<RouteOption>? cikarangLoopOptions(
  List<Station> allStations,
  String fromId,
  String toId,
) {
  final onLine =
      allStations.where((s) => s.lineIds.contains(cikarangLoopLine)).toList()
        ..sort(
          (a, b) => (a.stopOrderByLine[cikarangLoopLine] ?? 0).compareTo(
            b.stopOrderByLine[cikarangLoopLine] ?? 0,
          ),
        );
  final junction = onLine.indexWhere((s) => s.id == _loopJunction);
  if (junction < 0 || !onLine.any((s) => s.id == _loopSeam)) {
    return null;
  }
  final branch = onLine.sublist(0, junction); // before Jatinegara
  final ring = onLine.sublist(junction); // ring[0] is Jatinegara
  if (ring.length < 4) {
    return null;
  }
  final branchIndex = <String, int>{
    for (var i = 0; i < branch.length; i++) branch[i].id: i,
  };
  final ringIndex = <String, int>{
    for (var i = 0; i < ring.length; i++) ring[i].id: i,
  };
  final from = onLine.where((s) => s.id == fromId).firstOrNull;
  final to = onLine.where((s) => s.id == toId).firstOrNull;
  if (from == null || to == null || fromId == toId) {
    return null;
  }

  // Both on the branch: a plain straight ride.
  if (branchIndex.containsKey(fromId) && branchIndex.containsKey(toId)) {
    final a = branchIndex[fromId]!;
    final b = branchIndex[toId]!;
    final walk = a <= b
        ? branch.sublist(a, b + 1)
        : branch.sublist(b, a + 1).reversed.toList();
    return <RouteOption>[
      RouteOption(legs: <List<Station>>[walk]),
    ];
  }

  // Branch part from the station to Jatinegara (exclusive), and back.
  List<Station> branchToJunction(String id) =>
      branch.sublist(branchIndex[id]!).toList();

  final startRing = ringIndex[fromId] ?? 0;
  final endRing = ringIndex[toId] ?? 0;
  final n = ring.length;

  List<Station> walkFor(int direction) {
    final walk = <Station>[];
    if (branchIndex.containsKey(fromId)) {
      walk.addAll(branchToJunction(fromId));
    }
    var i = startRing;
    walk.add(ring[i]);
    while (i != endRing) {
      i = (i + direction + n) % n;
      walk.add(ring[i]);
    }
    if (branchIndex.containsKey(toId)) {
      walk.addAll(branchToJunction(toId).reversed);
    }
    return walk;
  }

  final options = <RouteOption>[];
  final seen = <String>{};
  for (final direction in const <int>[1, -1]) {
    if (startRing == endRing && direction == -1) {
      break; // only the branch is ridden; there is no "other way round".
    }
    final walk = walkFor(direction);
    final key = walk.map((s) => s.id).join('>');
    if (!seen.add(key)) continue;
    options.add(
      RouteOption(
        legs: _splitAtLoopChanges(walk, branchIndex),
        viaName: _viaName(walk),
      ),
    );
  }
  return _pruned(options);
}

/// Splits a loop walk into the trains that actually run it: change at
/// Kampung Bandan when riding on past it, and at Jatinegara when riding the
/// ring through it (neither neighbour is on the branch).
List<List<Station>> _splitAtLoopChanges(
  List<Station> walk,
  Map<String, int> branchIndex,
) {
  final legs = <List<Station>>[];
  var current = <Station>[walk.first];
  for (var i = 1; i < walk.length; i++) {
    final station = walk[i];
    current.add(station);
    final isInterior = i < walk.length - 1;
    if (!isInterior) break;
    final changeHere =
        station.id == _loopSeam ||
        (station.id == _loopJunction &&
            !branchIndex.containsKey(walk[i - 1].id) &&
            !branchIndex.containsKey(walk[i + 1].id));
    if (changeHere) {
      legs.add(current);
      current = <Station>[station];
    }
  }
  legs.add(current);
  return legs;
}

/// Name of the first well-known station passed (not boarded or left at).
String? _viaName(List<Station> walk) {
  if (walk.length < 3) return null;
  final interior = walk.sublist(1, walk.length - 1);
  for (final code in _loopViaCodes) {
    final hit = interior.where((s) => s.id == code).firstOrNull;
    if (hit != null) return hit.name;
  }
  return null;
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
      (a, b) => (a.stopOrderByLine[lineCode] ?? 0).compareTo(
        b.stopOrderByLine[lineCode] ?? 0,
      ),
    );
  final fromIndex = onLine.indexWhere((s) => s.id == fromId);
  final toIndex = onLine.indexWhere((s) => s.id == toId);
  if (fromIndex < 0 || toIndex < 0) {
    return const <Station>[];
  }
  if (fromIndex <= toIndex) {
    return onLine.sublist(fromIndex, toIndex + 1);
  }
  return onLine
      .sublist(toIndex, fromIndex + 1)
      .reversed
      .toList(growable: false);
}

/// The train a leg rides: its line, where it is heading (terminus) and the
/// service it runs, e.g. ("CIKARANG", "Kampung Bandan", "Cikarang – Kampung
/// Bandan via Pasar Senen"). Null when the leg's stations share no line.
typedef LegService = ({String lineCode, String headsign, String relation});

const _lineNames = <String, String>{
  'BOGOR': 'Bogor',
  'NAMBO': 'Nambo',
  'CIKARANG': 'Cikarang',
  'RANGKAS': 'Rangkasbitung',
  'RANGKASBITUNG': 'Rangkasbitung',
  'TANGERANG': 'Tangerang',
  'PRIOK': 'Tanjung Priok',
  'TANJUNG_PRIOK': 'Tanjung Priok',
  'YKPL': 'Yogyakarta',
};

/// "Commuter Line Cikarang" for a line code.
String commuterLineName(String lineCode) =>
    'Commuter Line ${_lineNames[lineCode] ?? lineCode}';

LegService? legService(List<Station> allStations, List<Station> leg) {
  if (leg.length < 2) return null;
  final common = leg.first.lineIds
      .where((line) => leg.every((s) => s.lineIds.contains(line)))
      .toList(growable: false);
  if (common.isEmpty) return null;
  // A leg on the ring part of the loop is a loop train even when its two
  // ends are also on another line (Manggarai, Jatinegara).
  final line =
      common.contains(cikarangLoopLine) && leg.any((s) => s.lineIds.length == 1)
      ? cikarangLoopLine
      : common.firstWhere(
          (l) => l != cikarangLoopLine,
          orElse: () => common.first,
        );
  final onLine = allStations.where((s) => s.lineIds.contains(line)).toList()
    ..sort(
      (a, b) => (a.stopOrderByLine[line] ?? 0).compareTo(
        b.stopOrderByLine[line] ?? 0,
      ),
    );
  if (onLine.length < 2) return null;

  if (line == cikarangLoopLine) {
    final loop = _loopService(onLine, leg);
    if (loop != null) return loop;
  }
  final a = onLine.indexWhere((s) => s.id == leg.first.id);
  final b = onLine.indexWhere((s) => s.id == leg.last.id);
  if (a < 0 || b < 0) return null;
  final headsign = b > a ? onLine.last.name : onLine.first.name;
  return (
    lineCode: line,
    headsign: headsign,
    relation: '${onLine.first.name} – ${onLine.last.name}',
  );
}

/// Loop trains run between Cikarang and Kampung Bandan, on one side of the
/// ring or the other.
LegService? _loopService(List<Station> onLine, List<Station> leg) {
  final junction = onLine.indexWhere((s) => s.id == _loopJunction);
  final seam = onLine.indexWhere((s) => s.id == _loopSeam);
  if (junction < 0 || seam < 0) return null;
  final cikarang = onLine.first.name;
  final kampungBandan = onLine[seam].name;
  int pos(Station s) => onLine.indexWhere((o) => o.id == s.id);

  // Side of the ring: stations between Jatinegara and Kampung Bandan in stop
  // order are the Manggarai side, after Kampung Bandan the Pasar Senen side.
  String? side;
  for (final s in leg) {
    final p = pos(s);
    if (p > junction && p < seam) side = 'Manggarai';
    if (p > seam) side = 'Pasar Senen';
  }

  // Heading to Kampung Bandan or back to Cikarang?
  bool towardSeam(int from, int to) {
    final fromRing = from >= junction;
    final toRing = to >= junction;
    if (!fromRing && !toRing) return to > from; // branch: up = into the city
    if (!fromRing && toRing) return true;
    if (fromRing && !toRing) return false;
    if (from == junction) return true; // leaving Jatinegara into the ring
    if (to == junction) return false;
    // Both on the ring: moving away from Jatinegara means toward the seam.
    final onManggaraiSide = from < seam || to < seam;
    if (from == seam) return false;
    if (to == seam) return true;
    return onManggaraiSide ? to > from : to < from;
  }

  final toKpb = towardSeam(pos(leg.first), pos(leg[1]));
  final via = side == null ? '' : ' via $side';
  return (
    lineCode: cikarangLoopLine,
    headsign: toKpb ? kampungBandan : cikarang,
    relation: '$cikarang – $kampungBandan$via',
  );
}
