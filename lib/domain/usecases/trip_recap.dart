import '../../core/database/app_database.dart';
import '../entities/transit_models.dart';
import 'krl_fare.dart';
import 'rail_distance.dart';

/// A station or route that appears most often in the history, with its count.
class RecapTally {
  const RecapTally({required this.label, required this.count});

  final String label;
  final int count;
}

/// Aggregate view of everything the rider has actually completed, built from
/// the device-local `CompletedTrips` log.
///
/// Every counted figure here (trips, time, stations, routes, days) comes
/// straight from stored rows and is exact. Distance and fare are the two
/// exceptions and are deliberately reported alongside [measuredTripCount]:
/// they can only be derived for trips whose two endpoints both resolve to
/// known stations sharing track geometry, so a history containing routes the
/// app has no geometry for measures fewer trips than it counts. Presenting
/// the two numbers together is what keeps "total spent" from quietly meaning
/// "total spent on the trips we happened to be able to measure."
class TripRecap {
  const TripRecap({
    required this.tripCount,
    required this.totalRideTime,
    required this.measuredTripCount,
    required this.totalDistanceMeters,
    required this.totalFareRupiah,
    required this.activeDayCount,
    required this.topStation,
    required this.topRoute,
    required this.longestTrip,
    required this.firstTripAt,
    required this.tripsByWeekday,
  });

  /// Builds the recap. [stations] is looked up by [Station.id], matching the
  /// ids stored on each completed trip.
  factory TripRecap.from(
    List<CompletedTrip> trips,
    Map<String, Station> stations,
  ) {
    if (trips.isEmpty) {
      return empty;
    }

    var rideTime = Duration.zero;
    var measured = 0;
    var distanceMeters = 0.0;
    var fare = 0;
    final stationCounts = <String, int>{};
    final routeCounts = <String, int>{};
    final activeDays = <String>{};
    final weekdayCounts = <int, int>{};
    CompletedTrip? longest;
    DateTime? firstAt;

    for (final trip in trips) {
      final duration = trip.arrivedAt.difference(trip.departedAt);
      // A clock that went backwards (device time change mid-trip, or a bad
      // row) must not subtract from the total.
      if (!duration.isNegative) {
        rideTime += duration;
        if (longest == null ||
            duration > longest.arrivedAt.difference(longest.departedAt)) {
          longest = trip;
        }
      }

      if (firstAt == null || trip.departedAt.isBefore(firstAt)) {
        firstAt = trip.departedAt;
      }

      final day = trip.departedAt;
      activeDays.add('${day.year}-${day.month}-${day.day}');
      weekdayCounts.update(day.weekday, (value) => value + 1, ifAbsent: () => 1);

      stationCounts.update(
        trip.originName,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      stationCounts.update(
        trip.destinationName,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      routeCounts.update(
        '${trip.originName} → ${trip.destinationName}',
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      final origin = stations[trip.originStationId];
      final destination = stations[trip.destinationStationId];
      if (origin != null && destination != null) {
        final meters = railTrackDistanceMeters(origin, destination);
        if (meters != null) {
          measured += 1;
          distanceMeters += meters;
          fare += krlFareRupiah(meters.round());
        }
      }
    }

    return TripRecap(
      tripCount: trips.length,
      totalRideTime: rideTime,
      measuredTripCount: measured,
      totalDistanceMeters: distanceMeters.round(),
      totalFareRupiah: fare,
      activeDayCount: activeDays.length,
      topStation: _top(stationCounts),
      topRoute: _top(routeCounts),
      longestTrip: longest,
      firstTripAt: firstAt,
      tripsByWeekday: weekdayCounts,
    );
  }

  final int tripCount;
  final Duration totalRideTime;

  /// How many of [tripCount] contributed to [totalDistanceMeters] and
  /// [totalFareRupiah]. Equal to [tripCount] when everything was measurable.
  final int measuredTripCount;
  final int totalDistanceMeters;
  final int totalFareRupiah;

  /// Distinct calendar days with at least one completed trip.
  final int activeDayCount;

  final RecapTally? topStation;
  final RecapTally? topRoute;
  final CompletedTrip? longestTrip;
  final DateTime? firstTripAt;

  /// Trip count per `DateTime.weekday` (1 = Monday ... 7 = Sunday). Weekdays
  /// with no trips are absent rather than zero.
  final Map<int, int> tripsByWeekday;

  bool get isEmpty => tripCount == 0;

  /// True when some trips could not be measured, so distance and fare are
  /// partial totals and the UI must say so.
  bool get hasUnmeasuredTrips => measuredTripCount < tripCount;

  static const empty = TripRecap(
    tripCount: 0,
    totalRideTime: Duration.zero,
    measuredTripCount: 0,
    totalDistanceMeters: 0,
    totalFareRupiah: 0,
    activeDayCount: 0,
    topStation: null,
    topRoute: null,
    longestTrip: null,
    firstTripAt: null,
    tripsByWeekday: <int, int>{},
  );

}

/// Highest-count entry, or null for an empty tally. Ties break on the label
/// so the same history always renders the same winner instead of shuffling
/// between builds.
RecapTally? _top(Map<String, int> counts) {
  if (counts.isEmpty) {
    return null;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return RecapTally(label: entries.first.key, count: entries.first.value);
}
