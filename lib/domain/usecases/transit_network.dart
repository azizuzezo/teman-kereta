import '../entities/transit_models.dart';

/// A rail network that is physically and commercially separate from the
/// others: a rider cannot get from one to the next on this app's trains, so a
/// route search must never join them.
enum TransitNetwork { jabodetabek, jogja }

/// `lines.code` of every line in the Yogyakarta network. Everything else is
/// Jabodetabek, which is why adding Jogja changes nothing for existing lines.
const _jogjaLineCodes = <String>{'YKPL'};

/// `stations.code` of the Yogyakarta network, used only for a station whose
/// provider did not populate [Station.lineIds] (mock/demo data).
const _jogjaStationCodes = <String>{
  'YK',
  'LPN',
  'MGW',
  'BBN',
  'SWT',
  'KT',
  'CE',
  'DL',
  'GW',
  'PWS',
  'SLO',
  'SK',
  'PL',
};

/// Short label for a network tab, e.g. on the live map.
String networkLabel(TransitNetwork network) => switch (network) {
  TransitNetwork.jabodetabek => 'Jabodetabek',
  TransitNetwork.jogja => 'Yogyakarta',
};

/// Network of a `lines.code` (any alias is fine: only Yogyakarta is special).
TransitNetwork networkOfLineCode(String lineCode) =>
    _jogjaLineCodes.contains(lineCode)
    ? TransitNetwork.jogja
    : TransitNetwork.jabodetabek;

TransitNetwork networkOfStation(Station station) {
  if (station.lineIds.isNotEmpty) {
    return station.lineIds.any(_jogjaLineCodes.contains)
        ? TransitNetwork.jogja
        : TransitNetwork.jabodetabek;
  }
  return _jogjaStationCodes.contains(station.code)
      ? TransitNetwork.jogja
      : TransitNetwork.jabodetabek;
}

bool sameNetwork(Station a, Station b) =>
    networkOfStation(a) == networkOfStation(b);

/// Stations a rider can pick as destination when leaving from [origin]: only
/// those on the same network, never [origin] itself.
List<Station> destinationsFor(Station origin, List<Station> all) => all
    .where((s) => s.id != origin.id && sameNetwork(origin, s))
    .toList(growable: false);

/// A sensible destination on [origin]'s network to fall back to when the
/// previously chosen one belongs to another network. Prefers the far end of
/// the origin's line so the result is a real, searchable trip.
Station? defaultDestinationFor(Station origin, List<Station> all) {
  final candidates = destinationsFor(origin, all);
  if (candidates.isEmpty) return null;
  final originOrder = origin.stopOrderByLine.values.firstOrNull;
  if (originOrder == null) {
    return (candidates.toList()..sort((a, b) => a.name.compareTo(b.name))).first;
  }
  int distance(Station s) =>
      ((s.stopOrderByLine.values.firstOrNull ?? originOrder) - originOrder)
          .abs();
  return candidates.reduce((a, b) => distance(b) > distance(a) ? b : a);
}

/// Message shown when origin and destination sit on different networks.
const crossNetworkMessage =
    'Stasiun asal dan tujuan berada di jaringan KRL yang berbeda '
    '(Jabodetabek dan Yogyakarta tidak tersambung). Pilih dua stasiun di jaringan yang sama.';
