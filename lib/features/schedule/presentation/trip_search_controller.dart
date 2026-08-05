import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/route_ranker.dart';

class TripSearchState {
  const TripSearchState({
    required this.originStationId,
    required this.destinationStationId,
    required this.departureAt,
    this.results = const <TransitTrip>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final String originStationId;
  final String destinationStationId;
  final DateTime departureAt;
  final List<TransitTrip> results;
  final bool isLoading;
  final String? errorMessage;

  TripSearchState copyWith({
    String? originStationId,
    String? destinationStationId,
    DateTime? departureAt,
    List<TransitTrip>? results,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TripSearchState(
      originStationId: originStationId ?? this.originStationId,
      destinationStationId: destinationStationId ?? this.destinationStationId,
      departureAt: departureAt ?? this.departureAt,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class TripSearchController extends Notifier<TripSearchState> {
  @override
  TripSearchState build() {
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
    state = state.copyWith(originStationId: value, clearError: true);
  }

  void swapStations() {
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
