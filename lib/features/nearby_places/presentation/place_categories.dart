import 'package:flutter/material.dart';

import '../../../core/utils/geo.dart';
import '../../../domain/entities/transit_models.dart';

/// One category as the rider sees it: a plain-language label and an icon.
///
/// `nearby_places.category` is free text (admin panel and community
/// submissions write whatever they like: "Kuliner", "Museum", "Masjid"), so
/// raw values are mapped onto a small set of known categories by keyword.
/// A value that matches nothing keeps its own wording and a generic icon, so
/// a new category an admin invents still shows up under its own name instead
/// of being hidden or mislabelled.
class PlaceCategory {
  const PlaceCategory({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;

  @override
  bool operator ==(Object other) => other is PlaceCategory && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

const _food = PlaceCategory(
  key: 'makan',
  label: 'Makan',
  icon: Icons.restaurant_rounded,
);
const _shopping = PlaceCategory(
  key: 'belanja',
  label: 'Belanja',
  icon: Icons.shopping_bag_outlined,
);
const _worship = PlaceCategory(
  key: 'ibadah',
  label: 'Ibadah',
  icon: Icons.mosque_outlined,
);
const _health = PlaceCategory(
  key: 'kesehatan',
  label: 'Kesehatan',
  icon: Icons.local_hospital_outlined,
);
const _money = PlaceCategory(
  key: 'uang',
  label: 'ATM & Bank',
  icon: Icons.account_balance_outlined,
);
const _transport = PlaceCategory(
  key: 'transportasi',
  label: 'Transportasi lanjutan',
  icon: Icons.directions_bus_outlined,
);
const _park = PlaceCategory(
  key: 'taman',
  label: 'Taman',
  icon: Icons.park_outlined,
);
const _sights = PlaceCategory(
  key: 'wisata',
  label: 'Wisata',
  icon: Icons.attractions_outlined,
);
const _lodging = PlaceCategory(
  key: 'penginapan',
  label: 'Penginapan',
  icon: Icons.hotel_outlined,
);
const _education = PlaceCategory(
  key: 'pendidikan',
  label: 'Pendidikan',
  icon: Icons.school_outlined,
);
const _facility = PlaceCategory(
  key: 'fasilitas',
  label: 'Fasilitas',
  icon: Icons.wc_outlined,
);

const List<(PlaceCategory, List<String>)> _keywords =
    <(PlaceCategory, List<String>)>[
      (
        _food,
        <String>[
          'kuliner',
          'makan',
          'makanan',
          'minum',
          'minuman',
          'restoran',
          'restaurant',
          'kafe',
          'cafe',
          'kopi',
          'warung',
          'jajan',
          'jajanan',
          'food',
        ],
      ),
      (
        _shopping,
        <String>[
          'belanja',
          'mall',
          'mal',
          'pasar',
          'toko',
          'minimarket',
          'supermarket',
          'swalayan',
        ],
      ),
      (
        _worship,
        <String>[
          'ibadah',
          'masjid',
          'musala',
          'mushola',
          'gereja',
          'pura',
          'vihara',
          'klenteng',
        ],
      ),
      (
        _health,
        <String>[
          'kesehatan',
          'rumah sakit',
          'klinik',
          'apotek',
          'puskesmas',
          'dokter',
        ],
      ),
      (_money, <String>['atm', 'bank', 'keuangan']),
      (
        _transport,
        <String>[
          'transportasi',
          'halte',
          'terminal',
          'bus',
          'angkot',
          'ojek',
          'transjakarta',
          'mrt',
          'lrt',
          'parkir',
        ],
      ),
      (_park, <String>['taman', 'ruang publik', 'park']),
      (
        _sights,
        <String>['wisata', 'museum', 'monumen', 'galeri', 'budaya', 'atraksi'],
      ),
      (_lodging, <String>['hotel', 'penginapan', 'hostel']),
      (_education, <String>['pendidikan', 'sekolah', 'kampus', 'universitas']),
      (_facility, <String>['fasilitas', 'toilet', 'layanan', 'umum']),
    ];

// Whole words only: "bus" must not match "business".
final List<(PlaceCategory, RegExp)> _matchers = <(PlaceCategory, RegExp)>[
  for (final (category, words) in _keywords)
    (
      category,
      RegExp('(?<![a-z])(?:${words.map(RegExp.escape).join('|')})(?![a-z])'),
    ),
];

/// Maps a raw `category` value to a [PlaceCategory].
PlaceCategory categoryOf(String raw) {
  final value = raw.trim().toLowerCase();
  for (final (category, matcher) in _matchers) {
    if (matcher.hasMatch(value)) {
      return category;
    }
  }
  final trimmed = raw.trim();
  final label = trimmed.isEmpty
      ? 'Lainnya'
      : trimmed[0].toUpperCase() + trimmed.substring(1);
  return PlaceCategory(
    key: 'lain:${trimmed.toLowerCase()}',
    label: label,
    icon: Icons.place_outlined,
  );
}

/// Places in one category, nearest first.
class PlaceGroup {
  const PlaceGroup(this.category, this.places);

  final PlaceCategory category;
  final List<NearbyPlace> places;

  int get count => places.length;
}

/// Distance used for ordering. A place with no recorded distance (stored as
/// 0 with no walking time) goes last instead of pretending to be at the gate.
int sortDistanceOf(NearbyPlace place) =>
    hasDistance(place) ? place.distanceMeters : 1 << 30;

bool hasDistance(NearbyPlace place) =>
    place.distanceMeters > 0 || place.walkingMinutes > 0;

/// Groups [places] by category. Inside a group the nearest place is first;
/// groups are ordered by their nearest place, so the most useful thing near
/// the station leads the page. Ties fall back to name for a stable order.
List<PlaceGroup> groupPlaces(List<NearbyPlace> places) {
  final byKey = <String, List<NearbyPlace>>{};
  final categories = <String, PlaceCategory>{};
  for (final place in places) {
    final category = categoryOf(place.category);
    categories[category.key] = category;
    byKey.putIfAbsent(category.key, () => <NearbyPlace>[]).add(place);
  }
  int compare(NearbyPlace a, NearbyPlace b) {
    final byDistance = sortDistanceOf(a).compareTo(sortDistanceOf(b));
    return byDistance != 0 ? byDistance : a.name.compareTo(b.name);
  }

  final groups = <PlaceGroup>[
    for (final entry in byKey.entries)
      PlaceGroup(categories[entry.key]!, entry.value..sort(compare)),
  ];
  groups.sort((a, b) {
    final byNearest = sortDistanceOf(
      a.places.first,
    ).compareTo(sortDistanceOf(b.places.first));
    return byNearest != 0
        ? byNearest
        : a.category.label.compareTo(b.category.label);
  });
  return groups;
}

/// Places of one category (by [PlaceCategory.key]), nearest first.
List<NearbyPlace> placesInCategory(List<NearbyPlace> places, String key) {
  for (final group in groupPlaces(places)) {
    if (group.category.key == key) {
      return group.places;
    }
  }
  return const <NearbyPlace>[];
}

/// Same pace as `NearestStationFinder` (83.3 m/min, about 5 km/h).
const double walkingMetersPerMinute = 83.3;

int walkingMinutesFor(int meters) {
  if (meters <= 0) {
    return 0;
  }
  final minutes = (meters / walkingMetersPerMinute).ceil();
  return minutes < 1 ? 1 : minutes;
}

/// `350 m • 4 menit jalan`. Uses the stored walking time when there is one,
/// otherwise derives it from the distance. Null when the place has no
/// distance at all, so the UI can leave the line out instead of showing 0.
String? walkingSummary(NearbyPlace place) {
  if (!hasDistance(place)) {
    return null;
  }
  final minutes = place.walkingMinutes > 0
      ? place.walkingMinutes
      : walkingMinutesFor(place.distanceMeters);
  if (place.distanceMeters <= 0) {
    return '$minutes menit jalan';
  }
  return '${formatDistanceMeters(place.distanceMeters.toDouble())} • '
      '$minutes menit jalan';
}

/// `5 tempat`.
String placeCountLabel(int count) => '$count tempat';

/// Puts [id] first in the recent-stations list, without duplicates, keeping at
/// most [max] entries.
List<String> pushRecent(List<String> current, String id, {int max = 4}) {
  final next = <String>[id, ...current.where((e) => e != id)];
  return next.take(max).toList(growable: false);
}
