// GENERATED, do not edit by hand.
//
// Corrected station coordinates keyed by station code. The `stations` table
// stores coordinates with only 3 decimals (about 100 m) and a few are far off
// (Nambo was 2.3 km from the real station), so station dots drifted away from
// the real track drawn from `rail_line_shapes.dart`.
//
// Source: station nodes of OpenStreetMap (ODbL, openstreetmap.org), matched by
// name to the closest candidate within 3 km of the stored coordinate and
// accepted only when the node lies within 150 m of the real track geometry.
// Stations without a trustworthy OSM node were projected onto the nearest
// track instead (marked below). Nothing here is invented.
//
// Applied by `applyStationCoordinateCorrection` when stations are loaded, so
// the map, "stasiun terdekat" and Jelajahi all use the same corrected point.
// To regenerate: re-run the OSM match against the current `stations` rows.
const stationCoordinateCorrectionsSource = 'OpenStreetMap contributors (ODbL)';

/// The coordinate to use for [code]: the corrected one when known, otherwise
/// the stored [latitude]/[longitude] unchanged.
({double latitude, double longitude}) applyStationCoordinateCorrection(
  String code,
  double latitude,
  double longitude,
) {
  final corrected = stationCoordinateCorrections[code];
  if (corrected == null) {
    return (latitude: latitude, longitude: longitude);
  }
  return (latitude: corrected.$1, longitude: corrected.$2);
}

const stationCoordinateCorrections = <String, (double, double)>{
  'AC': (-6.128115, 106.845137), // Ancol
  'AK': (-6.144737, 106.800779), // Angke
  'BJD': (-6.493234, 106.795025), // Bojonggede
  'BKS': (-6.236214, 106.998744), // Bekasi
  'BKST': (-6.246795, 107.018105), // Bekasi Timur
  'BOI': (-6.160214, 106.736134), // Bojong Indah
  'BOO': (-6.594289, 106.790769), // Bogor
  'BPR': (-6.172027, 106.665287), // Batu Ceper
  'BUA': (-6.215606, 106.923160), // Buaran
  'CBN': (-6.464248, 106.852520), // Cibinong
  'CC': (-6.329683, 106.618971), // Cicayur
  'CIT': (-6.261825, 107.083798), // Cibitung
  'CJT': (-6.354265, 106.509643), // Cilejit
  'CKI': (-6.198505, 106.841280), // Cikini
  'CKR': (-6.255314, 107.145073), // Cikarang
  'CKY': (-6.335738, 106.411655), // Cikoya
  'CLT': (-6.530724, 106.800688), // Cilebut
  'CSK': (-6.324445, 106.641626), // Cisauk
  'CTA': (-6.448824, 106.802362), // Citayam
  'CTR': (-6.335227, 106.331041), // Citeras (snapped to track)
  'CUK': (-6.219081, 106.952479), // Cakung
  'CW': (-6.242552, 106.858690), // Cawang
  'DAR': (-6.337970, 106.492563), // Daru
  'DP': (-6.404826, 106.817084), // Depok
  'DPB': (-6.391129, 106.821641), // Depok Baru
  'DRN': (-6.255201, 106.855167), // Duren Kalibata
  'DU': (-6.155276, 106.801297), // Duri
  'GDD': (-6.185911, 106.832566), // Gondangdia
  'GMR': (-6.176655, 106.830647), // Gambir
  'GRG': (-6.162035, 106.789610), // Grogol
  'GST': (-6.186153, 106.850871), // Gang Sentiong
  'JAKK': (-6.137583, 106.814620), // Jakarta Kota
  'JAY': (-6.141300, 106.823132), // Jayakarta
  'JIS': (-6.122821, 106.861360), // Jakarta International Stadium
  'JMU': (-6.288582, 106.729146), // Jurangmangu
  'JNG': (-6.214925, 106.870339), // Jatinegara
  'JTK': (-6.334994, 106.606613), // Jatake
  'JUA': (-6.166675, 106.830461), // Juanda
  'KAT': (-6.200770, 106.815833), // Karet (snapped to track)
  'KBY': (-6.237230, 106.782534), // Kebayoran
  'KDS': (-6.165966, 106.703728), // Kalideres
  'KLD': (-6.213319, 106.899413), // Klender
  'KLDB': (-6.217659, 106.940183), // Klender Baru
  'KMO': (-6.161703, 106.841401), // Kemayoran
  'KMT': (-6.193620, 106.856512), // Kramat
  'KPB': (-6.132702, 106.828487), // Kampung Bandan
  'KRI': (-6.224513, 106.979827), // Kranji
  'LNA': (-6.330308, 106.834679), // Lenteng Agung
  'MGB': (-6.149804, 106.826983), // Mangga Besar
  'MJ': (-6.332503, 106.396479), // Maja
  'MRI': (-6.210170, 106.849935), // Manggarai
  'MTR': (-6.197309, 106.858939), // Matraman (snapped to track)
  'NMO': (-6.466282, 106.906269), // Nambo
  'PDJ': (-6.276683, 106.744693), // Pondok Ranji
  'PDRG': (-6.460783, 106.824296), // Pondok Rajeg
  'PI': (-6.169735, 106.680752), // Poris
  'PLM': (-6.207920, 106.797232), // Palmerah
  'POC': (-6.369059, 106.832084), // Pondok Cina
  'POK': (-6.209124, 106.862342), // Pondok Jati
  'PRP': (-6.344344, 106.569846), // Parung Panjang
  'PSE': (-6.174423, 106.844574), // Pasar Senen
  'PSG': (-6.161252, 106.771908), // Pesing
  'PSM': (-6.283332, 106.844856), // Pasar Minggu
  'PSMB': (-6.262798, 106.851796), // Pasar Minggu Baru
  'RJW': (-6.145100, 106.836832), // Rajawali
  'RK': (-6.353075, 106.253132), // Rangkasbitung (snapped to track)
  'RU': (-6.314884, 106.676152), // Rawa Buntu
  'RW': (-6.162744, 106.722754), // Rawa Buaya
  'SDM': (-6.296844, 106.712647), // Sudimara
  'SRP': (-6.320153, 106.665584), // Serpong
  'SUD': (-6.202408, 106.823449), // Sudirman
  'SUDB': (-6.201594, 106.819717), // BNI City
  'SW': (-6.160667, 106.827655), // Sawah Besar
  'TB': (-6.258550, 107.055804), // Tambun
  'TEB': (-6.226398, 106.858439), // Tebet
  'TEJ': (-6.327318, 106.461659), // Tenjo
  'TGS': (-6.328836, 106.434060), // Tigaraksa
  'THB': (-6.185713, 106.810894), // Tanah Abang
  'THI': (-6.175170, 106.646710), // Tanah Tinggi
  'TKO': (-6.158627, 106.756573), // Taman Kota
  'TLM': (-6.257474, 107.111227), // Metland Telagamurni
  'TNG': (-6.176975, 106.632011), // Tangerang
  'TNT': (-6.308041, 106.838949), // Tanjung Barat
  'TPK': (-6.110588, 106.881467), // Tanjung Priok (snapped to track)
  'UI': (-6.360431, 106.831782), // Universitas Indonesia
  'UP': (-6.339345, 106.834263), // Universitas Pancasila
};
