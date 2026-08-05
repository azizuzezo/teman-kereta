import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/preferences_store.dart';

class FavoriteRouteController extends Notifier<String?> {
  late final PreferencesStore _store;

  @override
  String? build() {
    _store = ref.watch(preferencesStoreProvider);
    return _store.snapshot.favoriteRoute;
  }

  bool isFavorite(String originId, String destinationId) {
    return state == '$originId|$destinationId';
  }

  Future<void> toggle(String originId, String destinationId) async {
    final value = '$originId|$destinationId';
    state = state == value ? null : value;
    await _store.setFavoriteRoute(state);
  }
}

final favoriteRouteControllerProvider =
    NotifierProvider<FavoriteRouteController, String?>(
      FavoriteRouteController.new,
    );
