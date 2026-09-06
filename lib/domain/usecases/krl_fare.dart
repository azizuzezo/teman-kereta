import 'package:intl/intl.dart';

/// KAI Commuter's real distance-based KRL Jabodetabek tariff — the published
/// fare rule itself, not a guess: **Rp3.000 covers the first 25 km, and every
/// *started* 10 km beyond that adds Rp1.000**, repeating without a cap.
///
/// "Started" is the operative word and the reason this rounds up rather than
/// to nearest: 26 km and 35 km both sit in the same Rp4.000 band, but 35.1 km
/// already moves to Rp5.000. Rounding to nearest would under-charge the whole
/// back half of every band.
///
/// Takes **integer meters** rather than a double of kilometers on purpose.
/// Band edges land exactly on multiples of 10 km, and a float division like
/// `(35.0 - 25) / 10` can land on 1.0000000000000002 — which ceils to 2 and
/// silently reports a fare Rp1.000 too high at the precise boundary. Integer
/// arithmetic has no such edge.
int krlFareRupiah(int meters) {
  const baseFare = 3000;
  const includedMeters = 25000;
  const blockMeters = 10000;
  const blockFare = 1000;

  if (meters <= includedMeters) {
    return baseFare;
  }
  final extra = meters - includedMeters;
  // Integer ceiling division — every started block counts as a whole one.
  final blocks = (extra + blockMeters - 1) ~/ blockMeters;
  return baseFare + (blocks * blockFare);
}

final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

/// `6000` -> `Rp6.000`, in Indonesian thousands-separator convention.
String formatRupiah(int amount) => _rupiah.format(amount);
