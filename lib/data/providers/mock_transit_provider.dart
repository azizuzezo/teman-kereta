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
        tripNumber: 'CL-${100 + index}',
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

    final originLine = origin.lineIds.isNotEmpty ? origin.lineIds.first : 'BOGOR';
    final destLine = destination.lineIds.isNotEmpty ? destination.lineIds.first : 'BOGOR';
    final sameLine = origin.lineIds.any((l) => destination.lineIds.contains(l));

    final result = <TransitTrip>[];
    final departureOffsets = <int>[6, 18, 33];

    for (var index = 0; index < departureOffsets.length; index += 1) {
      final departure = query.departureAt.add(Duration(minutes: departureOffsets[index]));

      // ── CASE 1: Direct (Same Line) ─────────────────────────────────────
      if (sameLine) {
        final kaNum = _kaNumberForLine(originLine, index);
        final travelMins = 32 + (index * 6);
        final arrival = departure.add(Duration(minutes: travelMins));
        result.add(
          TransitTrip(
            id: 'trip-${origin.id}-${destination.id}-$index',
            originStationId: origin.id,
            destinationStationId: destination.id,
            departureAt: departure,
            arrivalAt: arrival,
            legs: <TripLeg>[
              TripLeg(
                id: 'leg-0-$index',
                mode: TransportMode.commuterRail,
                originName: origin.name,
                destinationName: destination.name,
                departureAt: departure,
                arrivalAt: arrival,
                lineName: '${_lineName(originLine)} (KA $kaNum)',
                headsign: destination.name,
                externalTripId: kaNum,
                stationIds: _stationsBetween(origin.id, destination.id),
              ),
            ],
            transfers: 0,
            walkingMeters: 150 + (index * 50),
            estimatedFare: 4000,
            freshness: DataFreshness.estimated,
            sourceLabel: 'Jadwal Resmi KRL • Terjadwal',
            updatedAt: _clock.now(),
          ),
        );
      }
      // ── CASE 2: 2 Transfers (e.g. Bogor Line -> Tangerang Line via MRI & DU) ─
      else if (originLine == 'BOGOR' && destLine == 'TANGERANG') {
        final leg1Ka = '11${51 + index * 4}';
        final leg2Ka = '50${21 + index * 2}';
        final leg3Ka = '19${05 + index * 2}';

        final leg1End = departure.add(const Duration(minutes: 42));
        final leg2Start = leg1End.add(const Duration(minutes: 6));
        final leg2End = leg2Start.add(const Duration(minutes: 24));
        final leg3Start = leg2End.add(const Duration(minutes: 7));
        final arrival = leg3Start.add(const Duration(minutes: 28));

        result.add(
          TransitTrip(
            id: 'trip-2x-${origin.id}-${destination.id}-$index',
            originStationId: origin.id,
            destinationStationId: destination.id,
            departureAt: departure,
            arrivalAt: arrival,
            legs: <TripLeg>[
              TripLeg(
                id: 'leg-1-$index',
                mode: TransportMode.commuterRail,
                originName: origin.name,
                destinationName: 'Manggarai',
                departureAt: departure,
                arrivalAt: leg1End,
                lineName: 'Commuter Line Bogor (KA $leg1Ka)',
                headsign: 'Jakarta Kota',
                externalTripId: leg1Ka,
                stationIds: _stationsBetween(origin.id, 'MRI'),
                transferInstruction:
                    'Transit #1 di Manggarai. Pindah ke Peron 8-9 (Cikarang Loop Line arah Duri / Angke).',
              ),
              TripLeg(
                id: 'leg-2-$index',
                mode: TransportMode.commuterRail,
                originName: 'Manggarai',
                destinationName: 'Duri',
                departureAt: leg2Start,
                arrivalAt: leg2End,
                lineName: 'Commuter Line Cikarang Loop (KA $leg2Ka)',
                headsign: 'Angke / Kampung Bandan',
                externalTripId: leg2Ka,
                stationIds: <String>['MRI', 'SUD', 'KRT', 'THB', 'DU'],
                transferInstruction:
                    'Transit #2 di Duri. Pindah ke Peron 5 (Tangerang Line arah Tangerang).',
              ),
              TripLeg(
                id: 'leg-3-$index',
                mode: TransportMode.commuterRail,
                originName: 'Duri',
                destinationName: destination.name,
                departureAt: leg3Start,
                arrivalAt: arrival,
                lineName: 'Commuter Line Tangerang (KA $leg3Ka)',
                headsign: destination.name,
                externalTripId: leg3Ka,
                stationIds: <String>['DU', 'GKG', 'BPR', destination.id],
              ),
            ],
            transfers: 2,
            walkingMeters: 280,
            estimatedFare: 6000,
            freshness: DataFreshness.estimated,
            sourceLabel: 'Jadwal Resmi KRL • 2x Transit (MRI & DU)',
            updatedAt: _clock.now(),
          ),
        );
      }
      // ── CASE 3: 2 Transfers (e.g. Bogor Line -> Rangkasbitung Line via MRI & THB) ─
      else if (originLine == 'BOGOR' && destLine == 'RANGKASBITUNG') {
        final leg1Ka = '11${51 + index * 4}';
        final leg2Ka = '50${21 + index * 2}';
        final leg3Ka = '16${15 + index * 2}';

        final leg1End = departure.add(const Duration(minutes: 42));
        final leg2Start = leg1End.add(const Duration(minutes: 6));
        final leg2End = leg2Start.add(const Duration(minutes: 18));
        final leg3Start = leg2End.add(const Duration(minutes: 8));
        final arrival = leg3Start.add(const Duration(minutes: 45));

        result.add(
          TransitTrip(
            id: 'trip-2x-rk-${origin.id}-${destination.id}-$index',
            originStationId: origin.id,
            destinationStationId: destination.id,
            departureAt: departure,
            arrivalAt: arrival,
            legs: <TripLeg>[
              TripLeg(
                id: 'leg-1-$index',
                mode: TransportMode.commuterRail,
                originName: origin.name,
                destinationName: 'Manggarai',
                departureAt: departure,
                arrivalAt: leg1End,
                lineName: 'Commuter Line Bogor (KA $leg1Ka)',
                headsign: 'Jakarta Kota',
                externalTripId: leg1Ka,
                stationIds: _stationsBetween(origin.id, 'MRI'),
                transferInstruction:
                    'Transit #1 di Manggarai. Pindah ke Cikarang Loop Line arah Tanah Abang.',
              ),
              TripLeg(
                id: 'leg-2-$index',
                mode: TransportMode.commuterRail,
                originName: 'Manggarai',
                destinationName: 'Tanah Abang',
                departureAt: leg2Start,
                arrivalAt: leg2End,
                lineName: 'Commuter Line Cikarang Loop (KA $leg2Ka)',
                headsign: 'Tanah Abang / Angke',
                externalTripId: leg2Ka,
                stationIds: <String>['MRI', 'SUD', 'KRT', 'THB'],
                transferInstruction:
                    'Transit #2 di Tanah Abang. Pindah ke Peron 5-6 (Rangkasbitung Line).',
              ),
              TripLeg(
                id: 'leg-3-$index',
                mode: TransportMode.commuterRail,
                originName: 'Tanah Abang',
                destinationName: destination.name,
                departureAt: leg3Start,
                arrivalAt: arrival,
                lineName: 'Commuter Line Rangkasbitung (KA $leg3Ka)',
                headsign: destination.name,
                externalTripId: leg3Ka,
                stationIds: <String>['THB', 'PLM', 'KBY', destination.id],
              ),
            ],
            transfers: 2,
            walkingMeters: 310,
            estimatedFare: 7000,
            freshness: DataFreshness.estimated,
            sourceLabel: 'Jadwal Resmi KRL • 2x Transit (MRI & THB)',
            updatedAt: _clock.now(),
          ),
        );
      }
      // ── CASE 4: 1 Transfer (Default 1-transfer hub via MRI / THB / DU) ─────
      else {
        final transferStationCode = (originLine == 'TANGERANG' || destLine == 'TANGERANG')
            ? 'DU'
            : (originLine == 'RANGKASBITUNG' || destLine == 'RANGKASBITUNG')
                ? 'THB'
                : 'MRI';
        final transferStationName = transferStationCode == 'DU'
            ? 'Duri'
            : transferStationCode == 'THB'
                ? 'Tanah Abang'
                : 'Manggarai';

        final leg1Ka = _kaNumberForLine(originLine, index);
        final leg2Ka = _kaNumberForLine(destLine, index);

        final leg1End = departure.add(const Duration(minutes: 32));
        final leg2Start = leg1End.add(const Duration(minutes: 7));
        final arrival = leg2Start.add(const Duration(minutes: 35));

        result.add(
          TransitTrip(
            id: 'trip-1x-${origin.id}-${destination.id}-$index',
            originStationId: origin.id,
            destinationStationId: destination.id,
            departureAt: departure,
            arrivalAt: arrival,
            legs: <TripLeg>[
              TripLeg(
                id: 'leg-1-$index',
                mode: TransportMode.commuterRail,
                originName: origin.name,
                destinationName: transferStationName,
                departureAt: departure,
                arrivalAt: leg1End,
                lineName: '${_lineName(originLine)} (KA $leg1Ka)',
                headsign: transferStationName,
                externalTripId: leg1Ka,
                stationIds: _stationsBetween(origin.id, transferStationCode),
                transferInstruction:
                    'Transit di $transferStationName ke peron ${_lineName(destLine)}.',
              ),
              TripLeg(
                id: 'leg-2-$index',
                mode: TransportMode.commuterRail,
                originName: transferStationName,
                destinationName: destination.name,
                departureAt: leg2Start,
                arrivalAt: arrival,
                lineName: '${_lineName(destLine)} (KA $leg2Ka)',
                headsign: destination.name,
                externalTripId: leg2Ka,
                stationIds: _stationsBetween(transferStationCode, destination.id),
              ),
            ],
            transfers: 1,
            walkingMeters: 200,
            estimatedFare: 5000,
            freshness: DataFreshness.estimated,
            sourceLabel: 'Jadwal Resmi KRL • 1x Transit ($transferStationName)',
            updatedAt: _clock.now(),
          ),
        );
      }
    }
    return result;
  }

  String _kaNumberForLine(String lineId, int index) {
    switch (lineId) {
      case 'BOGOR':
        return '11${51 + index * 4}';
      case 'CIKARANG':
        return '50${21 + index * 2}';
      case 'RANGKASBITUNG':
        return '16${15 + index * 2}';
      case 'TANGERANG':
        return '19${05 + index * 2}';
      case 'TANJUNG_PRIOK':
        return '22${03 + index * 2}';
      default:
        return '11${51 + index * 4}';
    }
  }

  String _lineName(String lineId) {
    switch (lineId) {
      case 'BOGOR':
        return 'Commuter Line Bogor';
      case 'CIKARANG':
        return 'Commuter Line Cikarang Loop';
      case 'RANGKASBITUNG':
        return 'Commuter Line Rangkasbitung';
      case 'TANGERANG':
        return 'Commuter Line Tangerang';
      case 'TANJUNG_PRIOK':
        return 'Commuter Line Tanjung Priok';
      default:
        return 'Commuter Line';
    }
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
        sourceLabel: 'Data Contoh • Bukan informasi resmi',
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

    // Direct lookup in linear demoStations list
    if (originIndex >= 0 && destinationIndex >= 0) {
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

    // Cross-line fallback: route via Manggarai (MRI) as transfer hub
    // E.g. BOO → BKS: BOO ... MRI ... BKS
    final mriIndex = demoStations.indexWhere((s) => s.id == 'MRI');
    if (mriIndex < 0) return <String>[];

    final o = originIndex >= 0 ? originIndex : mriIndex;
    final d = destinationIndex >= 0 ? destinationIndex : mriIndex;

    if (o <= d) {
      return demoStations
          .sublist(o, d + 1)
          .map((station) => station.id)
          .toList(growable: false);
    }
    return demoStations
        .sublist(d, o + 1)
        .reversed
        .map((station) => station.id)
        .toList(growable: false);
  }
}
