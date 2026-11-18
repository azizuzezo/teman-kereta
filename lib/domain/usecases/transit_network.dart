import '../entities/transit_models.dart';

/// A rail network that is physically and commercially separate from the
/// others: a rider cannot get from one to the next on this app's trains, so a
/// route search must never join them.
///
/// Mirrors `supabase/data/gapeka-2026/networks.json`: the value names are its
/// `id`s and [label] its `label`, in the file's order (also the tab order on
/// the live map). A new network in that file becomes a new value here plus
/// its lines in [networkByLineCode].
enum TransitNetwork {
  jabodetabek('Jabodetabek'),
  jogja('Yogyakarta'),
  bandung('Bandung Raya'),
  jatim('Jawa Timur'),
  semarang('Semarang'),
  sukabumi('Sukabumi-Cianjur'),
  banyuwangi('Jember-Banyuwangi');

  const TransitNetwork(this.label);

  /// Short name for a network tab, e.g. on the live map.
  final String label;

  /// Same as the `id` in `networks.json`.
  String get id => name;
}

/// `lines.code` -> network. The single source of truth for which network a
/// line belongs to (see `supabase/data/gapeka-2026/CONTRACT.md`, section D),
/// copied from `supabase/data/gapeka-2026/networks.json`. Keep the two in
/// sync when that file changes.
///
/// Besides the codes in that file, the long-form/legacy codes older and mock
/// data still use are kept as Jabodetabek aliases: `RANGKASBITUNG` (=
/// `RANGKAS`), `TANJUNG_PRIOK` (= `PRIOK`), `BEKASI`, `SERPONG`.
///
/// A code that is NOT in this map has no network: it is never assumed to be
/// Jabodetabek. See [networkOfLineCode] for what that means downstream.
const Map<String, TransitNetwork> networkByLineCode = <String, TransitNetwork>{
  // jabodetabek
  'BOGOR': TransitNetwork.jabodetabek,
  'CIKARANG': TransitNetwork.jabodetabek,
  'RANGKAS': TransitNetwork.jabodetabek,
  'TANGERANG': TransitNetwork.jabodetabek,
  'PRIOK': TransitNetwork.jabodetabek,
  'NAMBO': TransitNetwork.jabodetabek,
  'BST': TransitNetwork.jabodetabek,
  'MERAK': TransitNetwork.jabodetabek,
  'WALAHAR': TransitNetwork.jabodetabek,
  'JATILUHUR': TransitNetwork.jabodetabek,
  // jabodetabek: aliases used by older/mock data (not in networks.json)
  'RANGKASBITUNG': TransitNetwork.jabodetabek,
  'TANJUNG_PRIOK': TransitNetwork.jabodetabek,
  'BEKASI': TransitNetwork.jabodetabek,
  'SERPONG': TransitNetwork.jabodetabek,
  // jogja
  'YKPL': TransitNetwork.jogja,
  'YIA': TransitNetwork.jogja,
  'PRAMEKS': TransitNetwork.jogja,
  'SMO': TransitNetwork.jogja,
  'BATARAKRESNA': TransitNetwork.jogja,
  // bandung
  'BDR': TransitNetwork.bandung,
  'GARUT': TransitNetwork.bandung,
  'FEEDER': TransitNetwork.bandung,
  // jatim
  'DHOHO': TransitNetwork.jatim,
  'PENATARAN': TransitNetwork.jatim,
  'JENGGALA': TransitNetwork.jatim,
  'SUPAS': TransitNetwork.jatim,
  'ARJONEGORO': TransitNetwork.jatim,
  'BLORASURA': TransitNetwork.jatim,
  // semarang
  'KEDUNGSEPUR': TransitNetwork.semarang,
  // sukabumi
  'SILIWANGI': TransitNetwork.sukabumi,
  // banyuwangi
  'PANDANWANGI': TransitNetwork.banyuwangi,
};

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
String networkLabel(TransitNetwork network) => network.label;

/// Network of a `lines.code`, or null when the code is not in
/// [networkByLineCode].
///
/// Unknown codes are deliberately left without a network instead of being
/// treated as Jabodetabek:
/// - route search: a station whose lines are all unknown has no network, so
///   it is never on the "same network" as any other station (not even another
///   unknown one); no trip is searched or estimated for it and the form says
///   the network is not recognised ([unknownNetworkMessage]). A station with
///   at least one known line just uses the known ones;
/// - live map: such a station/line belongs to no network tab. With two or more
///   tabs it is not drawn (its track stays dimmed in the background); with a
///   single network tab (or none) everything is drawn as before.
TransitNetwork? networkOfLineCode(String lineCode) =>
    networkByLineCode[lineCode];

/// Every network [station] belongs to: the networks of its known lines. A
/// station can sit on more than one (Purwakarta: WALAHAR is Jabodetabek, BDR
/// and GARUT are Bandung Raya). Empty when it has lines but none is known.
///
/// A station without any line data (mock/demo providers) falls back to its
/// code: a known Yogyakarta code is Jogja, anything else Jabodetabek, which is
/// what that legacy data has always meant. Real data always has lines.
Set<TransitNetwork> networksOfStation(Station station) {
  if (station.lineIds.isEmpty) {
    return <TransitNetwork>{
      _jogjaStationCodes.contains(station.code)
          ? TransitNetwork.jogja
          : TransitNetwork.jabodetabek,
    };
  }
  return <TransitNetwork>{
    for (final lineCode in station.lineIds) ?networkOfLineCode(lineCode),
  };
}

/// The main network of [station] (the first of [networksOfStation] in
/// [TransitNetwork] order), or null when it has none. Prefer
/// [networksOfStation] / [sameNetwork] where a station on two networks
/// matters.
TransitNetwork? networkOfStation(Station station) {
  final networks = networksOfStation(station);
  for (final network in TransitNetwork.values) {
    if (networks.contains(network)) return network;
  }
  return null;
}

/// Networks both stations are on; empty when they share none (or either has
/// no known network).
Set<TransitNetwork> sharedNetworks(Station a, Station b) =>
    networksOfStation(a).intersection(networksOfStation(b));

/// True when the two stations share at least one known network. A station
/// with no known network matches nothing.
bool sameNetwork(Station a, Station b) => sharedNetworks(a, b).isNotEmpty;

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
    return (candidates.toList()..sort((a, b) => a.name.compareTo(b.name)))
        .first;
  }
  int distance(Station s) =>
      ((s.stopOrderByLine.values.firstOrNull ?? originOrder) - originOrder)
          .abs();
  return candidates.reduce((a, b) => distance(b) > distance(a) ? b : a);
}

/// Message shown when origin and destination sit on different networks.
const crossNetworkMessage =
    'Stasiun asal dan tujuan berada di jaringan kereta yang berbeda dan '
    'tidak tersambung. Pilih dua stasiun di jaringan yang sama.';

/// Message shown when origin or destination is on a line this app version
/// does not map to any network yet (see [networkOfLineCode]).
const unknownNetworkMessage =
    'Jaringan kereta untuk stasiun ini belum dikenali aplikasi, jadi rutenya '
    'belum bisa dicari. Coba perbarui aplikasi.';

/// The message for a pair that [sameNetwork] rejects.
String crossNetworkMessageFor(Station origin, Station destination) =>
    networksOfStation(origin).isEmpty || networksOfStation(destination).isEmpty
    ? unknownNetworkMessage
    : crossNetworkMessage;
