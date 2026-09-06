import '../../domain/entities/transit_models.dart';

/// Known landmark & area alias dictionary mapping common addresses/neighborhoods
/// to nearest KRL station IDs.
const Map<String, String> _landmarkAliasMap = <String, String>{
  'billabong': 'BGD', // Stasiun Bojonggede
  'tajurhalang': 'BGD', // Stasiun Bojonggede
  'tajur halang': 'BGD',
  'kemang bogor': 'BGD',
  'cilebut': 'CLT',
  'bogor': 'BOO',
  'baranangsiang': 'BOO',
  'sudirman': 'SUD',
  'dukuhatas': 'SUD',
  'dukuh atas': 'SUD',
  'wisma 46': 'SUD',
  'setiabudi': 'SUD',
  'kuningan': 'MGR', // Manggarai / Sudirman
  'monas': 'JUA', // Juanda
  'pasarsenen': 'PSE',
  'pasar senen': 'PSE',
  'senen': 'PSE',
  'gambir': 'GDD', // Gondangdia
  'gondangdia': 'GDD',
  'juanda': 'JUA',
  'cikini': 'CKI',
  'manggarai': 'MRI',
  'tebet': 'TBT',
  'cawang': 'CW',
  'duren kalibata': 'KBN',
  'kalibata': 'KBN',
  'pasar minggu': 'PSM',
  'depok': 'DP',
  'depok baru': 'POC',
  'margonda': 'POC',
  'ui': 'UI',
  'universitas indonesia': 'UI',
  'pondok cina': 'POC',
  'citayam': 'CTA',
  'bsd': 'SRP', // Serpong
  'bsd city': 'SRP',
  'serpong': 'SRP',
  'rawabuntu': 'RU',
  'rawa buntu': 'RU',
  'bintaro': 'PDJ', // Pondok Ranji
  'bintaro jaya': 'PDJ',
  'pondok ranji': 'PDJ',
  'jurangmangu': 'JMU',
  'jurang mangu': 'JMU',
  'sudimara': 'SDM',
  'tanah abang': 'THB',
  'kebayoran': 'KBY',
  'palmerah': 'PLM',
  'bekasi': 'BKS',
  'kranji': 'KRI',
  'cikarang': 'CKR',
  'tambun': 'TB',
  'klender': 'KLD',
  'buaran': 'BUA',
};

class ResolvedStationResult {
  const ResolvedStationResult({
    required this.station,
    required this.matchedAddress,
    required this.reason,
  });

  final Station station;
  final String matchedAddress;
  final String reason;
}

/// Resolves an address or landmark query to the best matching KRL station.
ResolvedStationResult? resolveAddressToNearestStation(
  String query,
  List<Station> stations,
) {
  final clean = query.trim().toLowerCase();
  if (clean.isEmpty || stations.isEmpty) return null;

  // 1. Direct landmark alias dictionary lookup
  for (final entry in _landmarkAliasMap.entries) {
    if (clean.contains(entry.key)) {
      final targetStation = stations.where((s) => s.id == entry.value).firstOrNull;
      if (targetStation != null) {
        return ResolvedStationResult(
          station: targetStation,
          matchedAddress: query,
          reason: 'Kawasan "${entry.key.toUpperCase()}" terdekat ke Stasiun ${targetStation.name}',
        );
      }
    }
  }

  // 2. Match directly against station name / ID / area text
  for (final station in stations) {
    final sName = station.name.toLowerCase();
    final sId = station.id.toLowerCase();
    if (clean.contains(sName) || sName.contains(clean) || clean == sId) {
      return ResolvedStationResult(
        station: station,
        matchedAddress: query,
        reason: 'Cocok dengan nama Stasiun ${station.name}',
      );
    }
  }

  // 3. Fallback: partial word matching
  final words = clean.split(RegExp(r'\s+'));
  for (final word in words) {
    if (word.length < 3) continue;
    final match = stations.where((s) => s.name.toLowerCase().contains(word)).firstOrNull;
    if (match != null) {
      return ResolvedStationResult(
        station: match,
        matchedAddress: query,
        reason: 'Kawasan terdekat dengan nama kata "${word.toUpperCase()}"',
      );
    }
  }

  return null;
}
