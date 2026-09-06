import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/route_ranker.dart';
import '../../stations/presentation/nearest_station_controller.dart';

class TripSearchState {
  const TripSearchState({
    required this.originStationId,
    required this.destinationStationId,
    required this.departureAt,
    this.results = const <TransitTrip>[],
    this.isLoading = false,
    this.errorMessage,
    this.finalDestinationQuery,
  });

  final String originStationId;
  final String destinationStationId;
  final DateTime departureAt;
  final List<TransitTrip> results;
  final bool isLoading;
  final String? errorMessage;

  /// Optional free-text final destination beyond the destination station
  /// itself (e.g. an office address) — carried onto `ActiveTripSession`
  /// when the trip starts, see `TripDetailPage`.
  final String? finalDestinationQuery;

  TripSearchState copyWith({
    String? originStationId,
    String? destinationStationId,
    DateTime? departureAt,
    List<TransitTrip>? results,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    Object? finalDestinationQuery = _unset,
  }) {
    return TripSearchState(
      originStationId: originStationId ?? this.originStationId,
      destinationStationId: destinationStationId ?? this.destinationStationId,
      departureAt: departureAt ?? this.departureAt,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      finalDestinationQuery: identical(finalDestinationQuery, _unset)
          ? this.finalDestinationQuery
          : finalDestinationQuery as String?,
    );
  }
}

const _unset = Object();

class TripSearchController extends Notifier<TripSearchState> {
  /// Whether the rider has explicitly picked an origin (dropdown, "gunakan
  /// sebagai asal", or the swap button) — once true, the nearest-station
  /// auto-fill below never overwrites their choice again.
  bool _originManuallySet = false;

  @override
  TripSearchState build() {
    // Auto-fills "Dari" with the rider's nearest station as soon as it
    // resolves, so most searches only need picking "Ke" — still fully
    // optional/changeable via [setOrigin]/[swapStations] below.
    ref.listen(nearestStationControllerProvider, (previous, next) {
      if (_originManuallySet) return;
      final nearest = next.asData?.value.firstOrNull;
      if (nearest != null) {
        state = state.copyWith(originStationId: nearest.station.id, clearError: true);
      }
    });
    return TripSearchState(
      originStationId: 'BOO',
      destinationStationId: 'SUD',
      departureAt: ref.watch(clockProvider).now(),
    );
  }

  void setDestination(String value) {
    state = state.copyWith(destinationStationId: value, clearError: true);
  }

  void setOrigin(String value) {
    _originManuallySet = true;
    state = state.copyWith(originStationId: value, clearError: true);
  }

  void setFinalDestinationQuery(String? value) {
    state = state.copyWith(
      finalDestinationQuery: (value == null || value.trim().isEmpty) ? null : value.trim(),
    );
  }

  void swapStations() {
    _originManuallySet = true;
    state = state.copyWith(
      originStationId: state.destinationStationId,
      destinationStationId: state.originStationId,
      clearError: true,
    );
  }

  Future<void> search() async {
    if (state.originStationId == state.destinationStationId) {
      state = state.copyWith(
        errorMessage: 'Stasiun awal dan tujuan harus berbeda.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final trips = await ref
          .read(transitScheduleProvider)
          .searchTrips(
            TripSearchQuery(
              originStationId: state.originStationId,
              destinationStationId: state.destinationStationId,
              departureAt: state.departureAt,
            ),
          );
      final ranked = const RouteRanker().rank(trips, state.departureAt);
      state = state.copyWith(results: ranked, isLoading: false);
    } on Object {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Jadwal lokal tidak dapat dimuat. Periksa data cache lalu coba lagi.',
      );
    }
  }
}

final tripSearchControllerProvider =
    NotifierProvider<TripSearchController, TripSearchState>(
      TripSearchController.new,
    );
