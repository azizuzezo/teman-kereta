import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/widgets/data_badges.dart';
import 'package:teman_kereta/data/providers/supabase_transit_provider.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';

/// Row parsing for the Supabase RPCs, before and after the GAPEKA 2026
/// migration adds `is_estimated` / `service_id` columns (CONTRACT.md, A).
void main() {
  final query = TripSearchQuery(
    originStationId: 'BOO',
    destinationStationId: 'SUD',
    departureAt: DateTime.utc(2026, 11, 18, 0, 0),
  );

  Map<String, dynamic> departureRow({Map<String, dynamic> extra = const {}}) =>
      <String, dynamic>{
        'trip_id': 'trip-1',
        'headsign': 'Jakarta Kota',
        'line_name': 'Commuter Line Bogor',
        'trip_number': '1001',
        'data_source': 'gtfs',
        'scheduled_departure': '2026-11-18T01:13:00Z',
        ...extra,
      };

  Map<String, dynamic> directRow({Map<String, dynamic> extra = const {}}) =>
      <String, dynamic>{
        'trip_id': 'trip-1',
        'external_trip_id': 'GJ26-1001',
        'service_date': '2026-11-18',
        'line_name': 'Commuter Line Bogor',
        'headsign': 'Jakarta Kota',
        'data_source': 'gtfs',
        'origin_sequence': 1,
        'destination_sequence': 4,
        'origin_departure': '2026-11-18T01:13:00Z',
        'destination_arrival': '2026-11-18T02:05:00Z',
        ...extra,
      };

  Map<String, dynamic> transferRow({Map<String, dynamic> extra = const {}}) =>
      <String, dynamic>{
        'outbound_trip_id': 'out-1',
        'inbound_trip_id': 'in-1',
        'transfer_station_code': 'MRI',
        'outbound_line_name': 'Commuter Line Bogor',
        'inbound_line_name': 'Commuter Line Cikarang',
        'outbound_headsign': 'Jakarta Kota',
        'inbound_headsign': 'Cikarang',
        'outbound_data_source': 'gtfs',
        'inbound_data_source': 'gtfs',
        'outbound_origin_departure': '2026-11-18T03:00:00Z',
        'outbound_transfer_arrival': '2026-11-18T03:40:00Z',
        'inbound_transfer_departure': '2026-11-18T03:47:00Z',
        'inbound_destination_arrival': '2026-11-18T04:10:00Z',
        ...extra,
      };

  TransitTrip transfer(Map<String, dynamic> row) => transferTripFromRow(
    row,
    query: query,
    originName: 'Bogor',
    destinationName: 'Bekasi',
    transferName: 'Manggarai',
    outboundStationCodes: const <String>['BOO', 'MRI'],
    inboundStationCodes: const <String>['MRI', 'BKS'],
    transferInstruction: 'Transit di Manggarai.',
  );

  TransitTrip direct(Map<String, dynamic> row) => directTripFromRow(
    row,
    query: query,
    originName: 'Bogor',
    destinationName: 'Sudirman',
    stationCodes: const <String>['BOO', 'DP', 'MRI', 'SUD'],
  );

  group('optional columns', () {
    test('absent, null or blank reads as false / null', () {
      expect(optionalFlag(<String, dynamic>{}, 'is_estimated'), isFalse);
      expect(
        optionalFlag(<String, dynamic>{'is_estimated': null}, 'is_estimated'),
        isFalse,
      );
      expect(optionalText(<String, dynamic>{}, 'service_id'), isNull);
      expect(
        optionalText(<String, dynamic>{'service_id': '  '}, 'service_id'),
        isNull,
      );
    });

    test('present values are read', () {
      expect(
        optionalFlag(<String, dynamic>{'is_estimated': true}, 'is_estimated'),
        isTrue,
      );
      expect(
        optionalText(<String, dynamic>{
          'service_id': 'GJ26_HARIAN',
        }, 'service_id'),
        'GJ26_HARIAN',
      );
    });
  });

  group('get_station_departures', () {
    test('a row from before the migration still parses', () {
      final d = departureFromRow(departureRow(), stationId: 'BOO');
      expect(d.isEstimated, isFalse);
      expect(d.serviceId, isNull);
      expect(d.scheduledAt, DateTime.utc(2026, 11, 18, 1, 13).toLocal());
      expect(d.freshness, DataFreshness.scheduled);
      expect(d.id, 'trip-1');
    });

    test('is_estimated and service_id are carried into the Departure', () {
      final d = departureFromRow(
        departureRow(
          extra: <String, dynamic>{
            'is_estimated': true,
            'service_id': 'GJ26_FAKULTATIF',
          },
        ),
        stationId: 'BOO',
      );
      expect(d.isEstimated, isTrue);
      expect(d.serviceId, fakultatifServiceId);
      expect(isFakultatifService(d.serviceId), isTrue);
    });

    test('a weekly re-dated row keeps a unique id and the moved time', () {
      final d = departureFromRow(
        departureRow(),
        stationId: 'BOO',
        shift: const Duration(days: 7),
      );
      expect(d.scheduledAt, DateTime.utc(2026, 11, 25, 1, 13).toLocal());
      expect(d.id, startsWith('trip-1@'));
    });
  });

  group('search_direct_trips', () {
    test('times are the timetable times exactly as returned', () {
      final trip = direct(directRow());
      expect(trip.departureAt, DateTime.utc(2026, 11, 18, 1, 13).toLocal());
      expect(trip.arrivalAt, DateTime.utc(2026, 11, 18, 2, 5).toLocal());
      expect(trip.legs.single.departureAt, trip.departureAt);
      expect(trip.legs.single.arrivalAt, trip.arrivalAt);
      expect(trip.freshness, DataFreshness.scheduled);
    });

    test('before the migration: nothing estimated, no service id', () {
      final trip = direct(directRow());
      expect(trip.departureEstimated, isFalse);
      expect(trip.arrivalEstimated, isFalse);
      expect(trip.isFakultatif, isFalse);
      expect(trip.legs.single.serviceId, isNull);
    });

    test('after the migration: per-end estimated flags and service id', () {
      final trip = direct(
        directRow(
          extra: <String, dynamic>{
            'origin_is_estimated': false,
            'destination_is_estimated': true,
            'service_id': 'GJ26_FAKULTATIF',
          },
        ),
      );
      expect(trip.departureEstimated, isFalse);
      expect(trip.arrivalEstimated, isTrue);
      expect(trip.legs.single.arrivalEstimated, isTrue);
      expect(trip.isFakultatif, isTrue);
    });
  });

  group('search_one_transfer_trips', () {
    test('times are as returned and nothing is estimated by default', () {
      final trip = transfer(transferRow());
      expect(trip.departureAt, DateTime.utc(2026, 11, 18, 3).toLocal());
      expect(trip.arrivalAt, DateTime.utc(2026, 11, 18, 4, 10).toLocal());
      expect(trip.legs[1].departureAt, DateTime.utc(2026, 11, 18, 3, 47).toLocal());
      expect(trip.transfers, 1);
      expect(trip.freshness, DataFreshness.scheduled);
      for (final leg in trip.legs) {
        expect(leg.departureEstimated, isFalse);
        expect(leg.arrivalEstimated, isFalse);
        expect(leg.serviceId, isNull);
      }
    });

    test('each of the four times and both service ids map to their leg', () {
      final trip = transfer(
        transferRow(
          extra: <String, dynamic>{
            'origin_is_estimated': true,
            'transfer_arrival_is_estimated': false,
            'transfer_departure_is_estimated': true,
            'destination_is_estimated': false,
            'first_service_id': 'GJ26_HARIAN',
            'second_service_id': 'GJ26_FAKULTATIF',
          },
        ),
      );
      expect(trip.legs[0].departureEstimated, isTrue);
      expect(trip.legs[0].arrivalEstimated, isFalse);
      expect(trip.legs[1].departureEstimated, isTrue);
      expect(trip.legs[1].arrivalEstimated, isFalse);
      expect(trip.legs[0].serviceId, 'GJ26_HARIAN');
      expect(trip.legs[1].serviceId, 'GJ26_FAKULTATIF');
      expect(trip.departureEstimated, isTrue);
      expect(trip.arrivalEstimated, isFalse);
      expect(trip.isFakultatif, isTrue);
    });
  });

  group('timetable results are not moved to "now"', () {
    test('order is by real departure and no time is rewritten', () {
      final later = direct(directRow()); // 01:13Z
      final earlier = direct(
        directRow(
          extra: <String, dynamic>{
            'trip_id': 'trip-0',
            'origin_departure': '2026-11-18T00:30:00Z',
            'destination_arrival': '2026-11-18T01:20:00Z',
          },
        ),
      );
      final viaTransfer = transfer(transferRow()); // 03:00Z

      final ordered = orderTimetableTrips(<TransitTrip>[
        viaTransfer,
        later,
        earlier,
      ]);

      expect(ordered.map((t) => t.id), <String>['trip-0', 'trip-1', 'out-1-in-1']);
      expect(ordered[0].departureAt, DateTime.utc(2026, 11, 18, 0, 30).toLocal());
      expect(ordered[0].arrivalAt, DateTime.utc(2026, 11, 18, 1, 20).toLocal());
      expect(ordered[1].departureAt, DateTime.utc(2026, 11, 18, 1, 13).toLocal());
      expect(ordered[2].departureAt, DateTime.utc(2026, 11, 18, 3).toLocal());
      // Not query time + 6 / + 18 / + 30 minutes, as the old rewrite did.
      expect(
        ordered[0].departureAt,
        isNot(query.departureAt.add(const Duration(minutes: 6))),
      );
    });
  });

  group('approximate time marker', () {
    test('only estimated times get a tilde', () {
      expect(approxTime('08:13', estimated: true), '~08:13');
      expect(approxTime('08:13', estimated: false), '08:13');
    });
  });
}
