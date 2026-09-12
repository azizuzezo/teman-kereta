import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/features/active_trip/presentation/trip_rail_timeline.dart';

List<RailStation> _stations(int count) => <RailStation>[
  for (var i = 0; i < count; i += 1)
    (name: 'Stasiun $i', transferInstruction: null),
];

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('renders every station when the route is short', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripRailTimeline(
          stations: _stations(5),
          currentIndex: 1,
          hopFraction: 0.3,
          reduceMotion: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i += 1) {
      expect(find.text('Stasiun $i'), findsOneWidget);
    }
    expect(find.textContaining('terlewat'), findsNothing);
  });

  testWidgets('collapses the middle of a long past stretch behind a divider', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripRailTimeline(
          stations: _stations(10),
          currentIndex: 6,
          hopFraction: 0,
          reduceMotion: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Origin and the stop right before "current" stay visible as anchors.
    expect(find.text('Stasiun 0'), findsOneWidget);
    expect(find.text('Stasiun 5'), findsOneWidget);
    expect(find.text('Stasiun 6'), findsOneWidget);
    // The stretch in between is hidden behind a single divider row.
    expect(find.text('Stasiun 1'), findsNothing);
    expect(find.text('Stasiun 4'), findsNothing);
    expect(find.text('4 stasiun terlewat'), findsOneWidget);

    await tester.tap(find.text('4 stasiun terlewat'));
    await tester.pumpAndSettle();

    expect(find.text('Stasiun 1'), findsOneWidget);
    expect(find.text('Stasiun 4'), findsOneWidget);
    expect(find.textContaining('terlewat'), findsNothing);
  });

  testWidgets('renders a transfer station with its instruction', (
    tester,
  ) async {
    final stations = <RailStation>[
      (name: 'A', transferInstruction: null),
      (name: 'B', transferInstruction: 'Transit ke Cikarang Line'),
      (name: 'C', transferInstruction: null),
    ];
    await tester.pumpWidget(
      _wrap(
        TripRailTimeline(
          stations: stations,
          currentIndex: 0,
          hopFraction: 0,
          reduceMotion: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Transit ke Cikarang Line'), findsOneWidget);
    expect(find.text('Transit'), findsOneWidget);
  });

  testWidgets(
    'the current-station pulse animates without motion reduced',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          TripRailTimeline(
            stations: _stations(3),
            currentIndex: 0,
            hopFraction: 0,
            reduceMotion: false,
          ),
        ),
      );
      // A repeating pulse never settles, so tick it a few times instead of
      // pumpAndSettle — this only needs to prove it animates without
      // throwing, not that it ever finishes.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 800));

      expect(tester.takeException(), isNull);
    },
  );
}
