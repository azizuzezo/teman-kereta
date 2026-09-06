import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/domain/usecases/krl_fare.dart';

void main() {
  group('krlFareRupiah', () {
    test('the first 25 km cost the base fare', () {
      expect(krlFareRupiah(0), 3000);
      expect(krlFareRupiah(1200), 3000);
      expect(krlFareRupiah(24999), 3000);
      expect(krlFareRupiah(25000), 3000);
    });

    test('each started 10 km beyond 25 adds Rp1.000', () {
      expect(krlFareRupiah(25001), 4000);
      expect(krlFareRupiah(30000), 4000);
      expect(krlFareRupiah(35000), 4000);
      expect(krlFareRupiah(35001), 5000);
      expect(krlFareRupiah(45000), 5000);
      expect(krlFareRupiah(45001), 6000);
    });

    test('band edges land exactly on the multiple, not one rupiah early', () {
      // The whole reason this takes integer meters: 35 km is the last
      // kilometre of the Rp4.000 band, not the first of Rp5.000.
      expect(krlFareRupiah(35000), 4000);
      expect(krlFareRupiah(55000), 6000);
      expect(krlFareRupiah(65000), 7000);
    });

    test('a single metre past a band edge costs a full extra block', () {
      // This is the sharp edge that makes measurement accuracy matter: the
      // whole difference between Rp6.000 and Rp7.000 can be one metre of
      // measured track. Documented as a test so nobody 'fixes' the ceiling
      // into a round-to-nearest later.
      expect(krlFareRupiah(55000), 6000);
      expect(krlFareRupiah(55001), 7000);
    });

    test('negative or nonsensical input still returns the base fare', () {
      expect(krlFareRupiah(-1), 3000);
    });
  });

  group('formatRupiah', () {
    test('formats with Indonesian thousands separators and no decimals', () {
      expect(formatRupiah(3000), 'Rp3.000');
      expect(formatRupiah(12000), 'Rp12.000');
    });
  });
}
