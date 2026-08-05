import 'dart:async';

import 'package:clock/clock.dart';

import '../../domain/entities/transit_models.dart';
import '../../domain/providers/transit_providers.dart';
import 'demo_data.dart';

class MockTransitProvider
    implements
        TransitScheduleProvider,
        TransitRealtimeProvider,
        PlacesProvider,
        StationProvider {
  MockTransitProvider({Clock? clock}) : _clock = clock ?? const Clock();

  final Clock _clock;

  @override
  Future<List<Departure>> getStationDepartures(
    String stationId,
    DateTime time,
  ) async {
    final station = await getStation(stationId);
    if (station == null) {
      return <Departure>[];
    }

    final destinations = stationId == 'JAKK'
        ? <String>['Bogor', 'Depok', 'Bogor']
        : <String>['Jakarta Kota', 'Manggarai', 'Jakarta Kota'];
    final offsets = <int>[5, 17, 31];

    return List<Departure>.generate(offsets.length, (index) {
      final scheduled = time.add(Duration(minutes: offsets[index]));
      return Departure(
        id: 'demo-$stationId-$index',
        stationId: stationId,
        destination: destinations[index],
        lineName: 'Commuter Line',
        scheduledAt: scheduled,
        expectedAt: scheduled,
        freshness: DataFreshness.estimated,
        sourceLabel: demoSource,
        platform: 'Peron belum tersedia',
        tripNumber: 'DEMO-${100 + index}',
        isDemo: true,
      );
    });
  }

  @override
  Future<Station?> getStation(String stationId) async {
    return demoStations.where((station) => station.id == stationId).firstOrNull;
  }

  @override
  Future<List<Station>> getStations() async => demoStations;

  @override
  Future<List<NearbyPlace>> getNearbyPlaces(
    double latitude,
    double longitude,
    PlaceFilter filter,
  ) async {
    return demoPlaces.where((place) {
      final matchesStation =
          filter.stationId == null || place.stationId == filter.stationId;
      final matchesCategory =
          filter.category == null || place.category == filter.category;
      return matchesStation &&
          matchesCategory &&
          place.distanceMeters <= filter.radiusMeters;
    }).toList(growable: false);
  }

  @override
  Future<List<TransitTrip>> searchTrips(TripSearchQuery query) async {
    final origin = await getStation(query.originStationId);
    final destination = await getStation(query.destinationStationId);
    if (origin == null || destination == null || origin == destination) {
      return <TransitTrip>[];
    }

    final stationIds = _stationsBetween(origin.id, destination.id);
    if (stationIds.isEmpty) {
      return <TransitTrip>[];
    }

    final result = <TransitTrip>[];
    for (var index = 0; index < 3; index += 1) {
      final departure = query.departureAt.add(Duration(minutes: 4 + (index * 8)));
      final travelMinutes = 48 + (stationIds.length * 2) + (index * 6);
      final arrival = departure.add(Duration(minutes: travelMinutes));
      final hasTransfer = destination.id == 'SUD';
      final legs = _buildLegs(
        index: index,
        origin: origin,
        destination: destination,
        stationIds: stationIds,
        departure: departure,
        arrival: arrival,
        hasTransfer: hasTransfer,
      );

      result.add(
        TransitTrip(
          id: 'demo-trip-${origin.id}-${destination.id}-$index',
          originStationId: origin.id,
          destinationStationId: destination.id,
          departureAt: departure,
          arrivalAt: arrival,
          legs: legs,
          transfers: hasTransfer ? 1 : 0,
          walkingMeters: 180 + (index * 90),
          estimatedFare: 5000 + (index * 1000),
          freshness: DataFreshness.estimated,
          sourceLabel: demoSource,
          updatedAt: _clock.now(),
          isDemo: true,
        ),
      );
    }
    return result;
  }

  @override
  Stream<List<ServiceAlert>> watchServiceAlerts() {
    return Stream<List<ServiceAlert>>.value(<ServiceAlert>[
      ServiceAlert(
        id: 'demo-alert-normal',
        title: 'Simulasi layanan normal',
        description:
            'Status ini hanya untuk pengembangan lokal dan bukan informasi operator.',
        status: ServiceStatus.normal,
        updatedAt: _clock.now(),
        sourceLabel: 'Data Demo • Bukan informasi resmi',
        isDemo: true,
      ),
    ]);
  }

  @override
  Stream<List<TripUpdate>> watchTripUpdates() {
    return Stream<List<TripUpdate>>.value(<TripUpdate>[]);
  }

  @override
  Stream<List<VehiclePosition>> watchVehiclePositions() {
    final updatedAt = _clock.now();
    return Stream<List<VehiclePosition>>.value(<VehiclePosition>[
      VehiclePosition(
        id: 'demo-vehicle-1',
        tripId: 'demo-trip-map-1',
        latitude: -6.2552,
        longitude: 106.8551,
        recordedAt: updatedAt,
        freshness: DataFreshness.estimated,
        sourceLabel: demoSource,
        previousStationId: 'DRN',
        nextStationId: 'TEB',
        isDemo: true,
      ),
    ]);
  }

  List<TripLeg> _buildLegs({
    required int index,
    required Station origin,
    required Station destination,
    required List<String> stationIds,
    required DateTime departure,
    required DateTime arrival,
    required bool hasTransfer,
  }) {
    final walkEnd = departure.add(const Duration(minutes: 4));
    final railStart = walkEnd.add(const Duration(minutes: 2));
    final railEnd = arrival.subtract(const Duration(minutes: 5));
    final transferIndex = hasTransfer ? stationIds.indexOf('MRI') : -1;
    final canSplitAtTransfer = transferIndex > 0 &&
        transferIndex < stationIds.length - 1;

    final railLegs = canSplitAtTransfer
        ? _buildTransferLegs(
            index: index,
            originName: origin.name,
            stationIds: stationIds,
            transferIndex: transferIndex,
            railStart: railStart,
            railEnd: railEnd,
            destinationName: destination.name,
          )
        : <TripLeg>[
            TripLeg(
              id: 'rail-$index',
              mode: TransportMode.commuterRail,
              originName: origin.name,
              destinationName: destination.name,
              departureAt: railStart,
              arrivalAt: railEnd,
              lineName: 'Bogor Line',
              headsign: destination.name,
              stationIds: stationIds,
            ),
          ];

    return <TripLeg>[
      TripLeg(
        id: 'walk-origin-$index',
        mode: TransportMode.walk,
        originName: 'Lokasi awal',
        destinationName: 'Stasiun ${origin.name}',
        departureAt: departure,
        arrivalAt: walkEnd,
        walkingMeters: 180 + (index * 90),
      ),
      ...railLegs,
      TripLeg(
        id: 'walk-destination-$index',
        mode: TransportMode.walk,
        originName: 'Stasiun ${destination.name}',
        destinationName: 'Tujuan akhir',
        departureAt: railEnd,
        arrivalAt: arrival,
        walkingMeters: 120,
      ),
    ];
  }

  List<TripLeg> _buildTransferLegs({
    required int index,
    required String originName,
    required List<String> stationIds,
    required int transferIndex,
    required DateTime railStart,
    required DateTime railEnd,
    required String destinationName,
  }) {
    final firstLegStations = stationIds.sublist(0, transferIndex + 1);
    final secondLegStations = stationIds.sublist(transferIndex);
    final transferAt = railStart.add(
      Duration(
        minutes:
            (railEnd.difference(railStart).inMinutes * firstLegStations.length) ~/
                stationIds.length,
      ),
    );
    final resumeAt = transferAt.add(const Duration(minutes: 6));

    return <TripLeg>[
      TripLeg(
        id: 'rail-$index-a',
        mode: TransportMode.commuterRail,
        originName: originName,
        destinationName: 'Manggarai',
        departureAt: railStart,
        arrivalAt: transferAt,
        lineName: 'Bogor Line',
        headsign: 'Jakarta Kota',
        stationIds: firstLegStations,
        transferInstruction:
            'Transit di Manggarai ke arah Cikarang Line. Peron harus diverifikasi dari sumber resmi.',
      ),
      TripLeg(
        id: 'rail-$index-b',
        mode: TransportMode.commuterRail,
        originName: 'Manggarai',
        destinationName: destinationName,
        departureAt: resumeAt,
        arrivalAt: railEnd,
        lineName: 'Cikarang Line',
        headsign: destinationName,
        stationIds: secondLegStations,
      ),
    ];
  }

  List<String> _stationsBetween(String originId, String destinationId) {
    final originIndex = demoStations.indexWhere((station) => station.id == originId);
    final destinationIndex = demoStations.indexWhere(
      (station) => station.id == destinationId,
    );
    if (originIndex < 0 || destinationIndex < 0) {
      return <String>[];
    }

    if (originIndex <= destinationIndex) {
      return demoStations
          .sublist(originIndex, destinationIndex + 1)
          .map((station) => station.id)
          .toList(growable: false);
    }

    return demoStations
        .sublist(destinationIndex, originIndex + 1)
        .reversed
        .map((station) => station.id)
        .toList(growable: false);
  }
}
