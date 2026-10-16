import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/config/app_environment.dart';
import 'place_categories.dart';

/// Where a place is, as far as the data says. `NearbyPlace` carries no
/// coordinates, so these are looked up separately when the backend has them.
@immutable
class PlaceTarget {
  const PlaceTarget({
    required this.name,
    required this.stationName,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String stationName;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Free-text query Maps can resolve: the place name qualified by the
  /// station, so "Warung Bu Tini" finds the one next to this station.
  String get query => '$name, Stasiun $stationName';
}

/// "Buka di peta": shows the place in the maps app. Coordinates when known,
/// otherwise a search for the name next to the station.
Uri buildOpenInMapUri(PlaceTarget target) {
  if (target.hasCoordinates) {
    return Uri.parse(
      'geo:${target.latitude},${target.longitude}'
      '?q=${target.latitude},${target.longitude}(${Uri.encodeComponent(target.name)})',
    );
  }
  return Uri.parse('geo:0,0?q=${Uri.encodeComponent(target.query)}');
}

Uri buildOpenInMapWebUri(PlaceTarget target) {
  final query = target.hasCoordinates
      ? '${target.latitude},${target.longitude}'
      : target.query;
  return Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
  );
}

/// "Petunjuk jalan": walking directions from the station to the place.
Uri buildWalkingDirectionsUri(
  PlaceTarget target, {
  required double stationLatitude,
  required double stationLongitude,
}) {
  final destination = target.hasCoordinates
      ? '${target.latitude},${target.longitude}'
      : target.query;
  return Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&origin=$stationLatitude,$stationLongitude'
    '&destination=${Uri.encodeComponent(destination)}'
    '&travelmode=walking',
  );
}

/// Coordinates of a community/admin place, only when the backend is
/// reachable and the row has them. Never guesses.
Future<(double, double)?> fetchPlaceCoordinates(String placeId) async {
  if (!AppEnvironment.supabaseEnabled) {
    return null;
  }
  try {
    final row = await Supabase.instance.client
        .from('nearby_places')
        .select('latitude, longitude')
        .eq('id', placeId)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    final lat = (row['latitude'] as num?)?.toDouble();
    final lon = (row['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null || (lat == 0 && lon == 0)) {
      return null;
    }
    return (lat, lon);
  } on Object {
    return null;
  }
}

/// Opens [primary], falling back to [fallback]. Returns false if neither
/// could be opened, so the caller can say so.
Future<bool> launchWithFallback(Uri primary, Uri fallback) async {
  try {
    if (await canLaunchUrl(primary)) {
      return await launchUrl(primary, mode: LaunchMode.externalApplication);
    }
    return await launchUrl(fallback, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}

const _recentKey = 'explore_recent_stations';

/// Stations the rider looked at recently (station ids, newest first), kept on
/// the device only.
class ExploreRecentsController extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    try {
      return await SharedPreferencesAsync().getStringList(_recentKey) ??
          const <String>[];
    } on Object {
      return const <String>[];
    }
  }

  Future<void> add(String stationId) async {
    final next = pushRecent(state.asData?.value ?? const <String>[], stationId);
    state = AsyncData<List<String>>(next);
    try {
      await SharedPreferencesAsync().setStringList(_recentKey, next);
    } on Object {
      // Recents are a convenience; the in-memory list still works.
    }
  }
}

final exploreRecentsProvider =
    AsyncNotifierProvider<ExploreRecentsController, List<String>>(
      ExploreRecentsController.new,
    );
