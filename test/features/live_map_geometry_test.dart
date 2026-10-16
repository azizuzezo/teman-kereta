import 'dart:ui';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/live_map/presentation/live_map_geometry.dart';
import 'package:teman_kereta/features/live_map/presentation/map_tiles.dart';

Station _station(
  String id,
  double lat,
  double lon, {
  List<String> lines = const <String>[],
  Map<String, int> order = const <String, int>{},
}) => Station(
  id: id,
  code: id,
  name: 'Stasiun $id',
  latitude: lat,
  longitude: lon,
  lineIds: lines,
  stopOrderByLine: order,
);

void main() {
  group('simplifyPolyline', () {
    test('drops points on a straight line, keeps both endpoints', () {
      final line = <LatLng>[
        for (var i = 0; i <= 10; i += 1) LatLng(-6.2, 106.8 + i * 0.001),
      ];
      final out = simplifyPolyline(line, 2);
      expect(out, <LatLng>[line.first, line.last]);
    });

    test('keeps a real corner', () {
      final line = <LatLng>[
        const LatLng(-6.2, 106.80),
        const LatLng(-6.2, 106.81),
        const LatLng(-6.21, 106.81),
      ];
      expect(simplifyPolyline(line, 5), line);
    });

    test('removes a wiggle smaller than the tolerance but not a larger one', () {
      // ~1.1 m sideways wiggle in the middle of a ~1.1 km line.
      final wiggle = <LatLng>[
        const LatLng(-6.2, 106.800),
        const LatLng(-6.20001, 106.805),
        const LatLng(-6.2, 106.810),
      ];
      expect(simplifyPolyline(wiggle, 5), hasLength(2));
      expect(simplifyPolyline(wiggle, 0.5), hasLength(3));
    });

    test('handles a closed loop whose first and last point coincide', () {
      final loop = <LatLng>[
        const LatLng(-6.2, 106.8),
        const LatLng(-6.2, 106.82),
        const LatLng(-6.22, 106.82),
        const LatLng(-6.22, 106.8),
        const LatLng(-6.2, 106.8),
      ];
      expect(simplifyPolyline(loop, 5), loop);
    });

    test('short or zero-tolerance input is returned unchanged', () {
      final two = <LatLng>[const LatLng(0, 0), const LatLng(1, 1)];
      expect(simplifyPolyline(two, 10), two);
      final three = <LatLng>[
        const LatLng(0, 0),
        const LatLng(0.5, 0.5),
        const LatLng(1, 1),
      ];
      expect(simplifyPolyline(three, 0), three);
    });

    test('does not mutate its input', () {
      final line = <LatLng>[
        for (var i = 0; i <= 5; i += 1) LatLng(-6.2, 106.8 + i * 0.001),
      ];
      simplifyPolyline(line, 5);
      expect(line, hasLength(6));
    });
  });

  test('tolerance halves with each zoom level', () {
    final z12 = simplifyToleranceForZoom(12);
    final z13 = simplifyToleranceForZoom(13);
    expect(z12 / z13, closeTo(2, 1e-9));
    expect(z12, closeTo(38, 1)); // about 38 m per pixel at z12 near Jakarta
  });

  group('line identity', () {
    test('long codes resolve to the short production codes', () {
      expect(canonicalLineId('RANGKASBITUNG'), 'RANGKAS');
      expect(canonicalLineId('TANJUNG_PRIOK'), 'PRIOK');
      expect(canonicalLineId('BOGOR'), 'BOGOR');
    });

    test('names are plain Indonesian, unknown codes are humanised', () {
      expect(lineShortName('TANJUNG_PRIOK'), 'Tanjung Priok');
      expect(lineLongName('BOGOR'), 'Lintas Bogor');
      expect(lineShortName('LINGKAR_BARU'), 'Lingkar Baru');
    });

    test('lineIdsOf merges aliases and sorts', () {
      final ids = lineIdsOf(<Station>[
        _station('A', 0, 0, lines: <String>['RANGKASBITUNG', 'BOGOR']),
        _station('B', 0, 0, lines: <String>['RANGKAS']),
      ]);
      expect(ids, <String>['BOGOR', 'RANGKAS']);
    });
  });

  group('line tracks', () {
    final shapes = <String, List<List<double>>>{
      'BOGOR': <List<double>>[
        <double>[-6.2, 106.80],
        <double>[-6.2, 106.81],
        <double>[-6.2, 106.82],
        <double>[-6.21, 106.82],
      ],
    };

    test('uses real geometry when a shape exists, under either code', () {
      final track = buildLineTrack(
        lineId: 'BOGOR',
        stations: const <Station>[],
        shapes: shapes,
      );
      expect(track, isNotNull);
      expect(track!.isRealTrack, isTrue);
      // The middle point of the straight stretch is removed, the corner kept.
      expect(track.points, hasLength(3));

      final alias = buildLineTrack(
        lineId: 'RANGKASBITUNG',
        stations: const <Station>[],
        shapes: <String, List<List<double>>>{'RANGKAS': shapes['BOGOR']!},
      );
      expect(alias?.isRealTrack, isTrue);
      expect(alias?.lineId, 'RANGKAS');
    });

    test('falls back to stations in stop order and says it is not real', () {
      final stations = <Station>[
        _station('C', -6.30, 106.8, lines: <String>['X'], order: <String, int>{'X': 3}),
        _station('A', -6.10, 106.8, lines: <String>['X'], order: <String, int>{'X': 1}),
        _station('B', -6.20, 106.8, lines: <String>['X'], order: <String, int>{'X': 2}),
      ];
      final track = buildLineTrack(
        lineId: 'X',
        stations: stations,
        shapes: shapes,
      );
      expect(track!.isRealTrack, isFalse);
      expect(track.points.map((p) => p.latitude), <double>[-6.10, -6.20, -6.30]);
    });

    test('returns null when there is nothing to draw', () {
      expect(
        buildLineTrack(
          lineId: 'X',
          stations: <Station>[_station('A', 0, 0, lines: <String>['X'])],
          shapes: shapes,
        ),
        isNull,
      );
    });

    test('without stop order, chains stations from one end of the line', () {
      // An east-west line given in scrambled order.
      final stations = <Station>[
        _station('C', -6.2, 106.90, lines: <String>['X']),
        _station('A', -6.2, 106.70, lines: <String>['X']),
        _station('D', -6.2, 107.00, lines: <String>['X']),
        _station('B', -6.2, 106.80, lines: <String>['X']),
      ];
      final ids = orderStationsOnLine(stations, 'X').map((s) => s.id).toList();
      expect(
        listEquals(ids, <String>['A', 'B', 'C', 'D']) ||
            listEquals(ids, <String>['D', 'C', 'B', 'A']),
        isTrue,
        reason: 'got $ids',
      );
    });
  });

  group('colours', () {
    const lightMap = Color(0xFFF2EFE9);
    const darkMap = Color(0xFF141414);

    test('a pale colour is darkened until it reads on a light map', () {
      const pale = Color(0xFFFFE680);
      final fixed = ensureContrast(pale, lightMap);
      expect(contrastRatio(fixed, lightMap), greaterThanOrEqualTo(3));
    });

    test('a dark colour is lightened until it reads on a dark map', () {
      const navy = Color(0xFF17376B);
      final fixed = ensureContrast(navy, darkMap);
      expect(contrastRatio(fixed, darkMap), greaterThanOrEqualTo(3));
    });

    test('a colour that already reads is left alone', () {
      const red = Color(0xFFC81E28);
      expect(ensureContrast(red, lightMap), red);
    });

    test('database colours win, fallbacks fill the gaps, both pass contrast', () {
      final colors = resolveLineColors(
        lineIds: <String>['BOGOR', 'RANGKASBITUNG', 'NOCOLOR'],
        dbColors: const <String, Color>{
          'BOGOR': Color(0xFFD01F26),
          'RANGKAS': Color(0xFF1E8A4C),
        },
        mapBackground: lightMap,
      );
      expect(colors.keys, <String>['BOGOR', 'RANGKAS', 'NOCOLOR']);
      expect(colors['BOGOR'], const Color(0xFFD01F26));
      expect(colors['RANGKAS'], const Color(0xFF1E8A4C));
      for (final c in colors.values) {
        expect(contrastRatio(c, lightMap), greaterThanOrEqualTo(3));
      }
    });
  });

  group('hit testing and labels', () {
    test('nearest point within the radius wins, outside it is null', () {
      const points = <Offset>[Offset(10, 10), Offset(40, 10), Offset(42, 12)];
      expect(nearestPointWithin(points, const Offset(41, 11), 10), 1);
      expect(nearestPointWithin(points, const Offset(200, 200), 30), isNull);
    });

    test('labels that overlap an earlier, higher-priority one are dropped', () {
      final placed = placeLabels(<Rect>[
        const Rect.fromLTWH(0, 0, 50, 12),
        const Rect.fromLTWH(40, 4, 50, 12),
        const Rect.fromLTWH(0, 30, 50, 12),
      ]);
      expect(placed, <bool>[true, false, true]);
    });
  });

  group('station search', () {
    final stations = <Station>[
      Station(id: 'MRI', code: 'MRI', name: 'Manggarai', latitude: 0, longitude: 0),
      Station(id: 'SUD', code: 'SUD', name: 'Sudirman', latitude: 0, longitude: 0),
      Station(id: 'TNG', code: 'TNG', name: 'Tanah Abang', latitude: 0, longitude: 0),
      Station(id: 'SRG', code: 'SRG', name: 'Pasar Minggu Baru', latitude: 0, longitude: 0),
    ];

    test('prefix matches come before contains matches, case-insensitive', () {
      // 'Pasar Minggu Baru' sorts first alphabetically, but only contains 's';
      // 'Sudirman' starts with it, so it leads.
      final names = searchStations(stations, 'S').map((s) => s.name).toList();
      expect(names, <String>['Sudirman', 'Pasar Minggu Baru']);
    });

    test('matches by code and returns everything sorted when empty', () {
      expect(searchStations(stations, 'sud').single.id, 'SUD');
      expect(
        searchStations(stations, '').map((s) => s.name),
        <String>['Manggarai', 'Pasar Minggu Baru', 'Sudirman', 'Tanah Abang'],
      );
      expect(searchStations(stations, 'zzz'), isEmpty);
    });
  });

  group('freshVehicles', () {
    VehiclePosition v(String id, DateTime at) => VehiclePosition(
      id: id,
      tripId: id,
      latitude: 0,
      longitude: 0,
      recordedAt: at,
      freshness: DataFreshness.estimated,
      sourceLabel: 'x',
    );

    test('drops reports older than five minutes', () {
      final now = DateTime(2026, 10, 15, 8);
      final out = freshVehicles(<VehiclePosition>[
        v('fresh', now.subtract(const Duration(minutes: 1))),
        v('edge', now.subtract(const Duration(minutes: 5))),
        v('stale', now.subtract(const Duration(minutes: 6))),
      ], now);
      expect(out.map((e) => e.id), <String>['fresh', 'edge']);
    });
  });

  group('formatting', () {
    test('clock and wait text', () {
      expect(formatClock(DateTime(2026, 1, 1, 7, 5)), '07:05');
      expect(formatWait(const Duration(seconds: 20)), 'Sekarang');
      expect(formatWait(const Duration(minutes: 5, seconds: 30)), '5 menit');
      expect(formatWait(const Duration(minutes: 70)), '1 jam 10 menit');
      expect(formatWait(const Duration(minutes: 120)), '2 jam');
    });
  });

  group('tile cache', () {
    test('file name is stable and filesystem safe', () {
      expect(
        tileCacheFileName('https://tile.openstreetmap.org/12/3263/2118.png'),
        'tile.openstreetmap.org_12_3263_2118.png',
      );
    });

    test('freshness thresholds', () {
      expect(tileFreshnessFor(const Duration(days: 1)), TileFreshness.fresh);
      expect(tileFreshnessFor(const Duration(days: 10)), TileFreshness.stale);
      expect(tileFreshnessFor(const Duration(days: 40)), TileFreshness.expired);
    });

    test('tile health reports degraded only after repeated failures', () {
      final tracker = TileHealthTracker(threshold: 3);
      addTearDown(tracker.dispose);
      tracker.recordError();
      tracker.recordError();
      expect(tracker.isDegraded, isFalse);
      tracker.recordError();
      expect(tracker.isDegraded, isTrue);
      tracker.reset();
      expect(tracker.isDegraded, isFalse);
    });
  });
}
