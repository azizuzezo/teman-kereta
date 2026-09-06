import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/domain/usecases/transfer_platform_guidance.dart';

void main() {
  String? guide(String from, String at, String next) =>
      transferPlatformInstruction(approachingFromName: from, transferName: at, nextName: next);

  test('Manggarai, from Bogor/Jakarta Kota', () {
    expect(guide('Bogor', 'Manggarai', 'Matraman'), 'Transit ke Peron Bawah 3/4.');
    expect(guide('Jakarta Kota', 'Manggarai', 'Matraman'), 'Transit ke Peron Bawah 3/4.');
    expect(guide('Bogor', 'Manggarai', 'Sudirman'), 'Transit ke Peron Bawah 1/2.');
  });

  test('Manggarai, from Tebet/Cikini (real adjacent stop for any Bogor-line rider)', () {
    // Callers pass the real immediately-preceding stop, not the trip's
    // ultimate origin — every Bogor-line rider (Bogor, Bojonggede, Depok,
    // Citayam...) funnels through Tebet right before Manggarai, so this
    // must match just as well as the literal 'Bogor' example does.
    expect(guide('Tebet', 'Manggarai', 'Matraman'), 'Transit ke Peron Bawah 3/4.');
    expect(guide('Tebet', 'Manggarai', 'Sudirman'), 'Transit ke Peron Bawah 1/2.');
    expect(guide('Cikini', 'Manggarai', 'Sudirman'), 'Transit ke Peron Bawah 1/2.');
  });

  test('Manggarai, from Sudirman/Matraman', () {
    expect(guide('Sudirman', 'Manggarai', 'Tebet'), 'Transit ke Peron Atas 11/12.');
    expect(guide('Matraman', 'Manggarai', 'Tebet'), 'Transit ke Peron Atas 11/12.');
    expect(guide('Sudirman', 'Manggarai', 'Cikini'), 'Transit ke Peron Atas 9/10.');
  });

  test('Tanah Abang, from Karet/BNI City/Duri to Palmerah', () {
    expect(guide('Karet', 'Tanah Abang', 'Palmerah'), 'Transit ke Peron 5/6.');
    expect(guide('BNI City', 'Tanah Abang', 'Palmerah'), 'Transit ke Peron 5/6.');
    expect(guide('Duri', 'Tanah Abang', 'Palmerah'), 'Transit ke Peron 5/6.');
  });

  test('Tanah Abang, from Palmerah', () {
    expect(guide('Palmerah', 'Tanah Abang', 'Karet'), 'Transit ke Peron 2/3.');
    expect(guide('Palmerah', 'Tanah Abang', 'BNI City'), 'Transit ke Peron 2/3.');
    expect(guide('Palmerah', 'Tanah Abang', 'Duri'), 'Transit ke Peron 1.');
  });

  test('Duri, from Tanah Abang/Angke to Grogol', () {
    expect(guide('Tanah Abang', 'Duri', 'Grogol'), 'Transit ke Peron 5.');
    expect(guide('Angke', 'Duri', 'Grogol'), 'Transit ke Peron 5.');
  });

  test('Jatinegara — Pondok Jati/Klender via PSE to Matraman', () {
    expect(guide('Pondok Jati', 'Jatinegara', 'Matraman'), 'Transit ke Peron 2.');
    expect(guide('Klender', 'Jatinegara', 'Matraman'), 'Transit ke Peron 2.');
  });

  test('Jatinegara — Matraman/Klender via MRI to Pondok Jati', () {
    expect(guide('Matraman', 'Jatinegara', 'Pondok Jati'), 'Transit ke Peron 5/6.');
    expect(guide('Klender', 'Jatinegara', 'Pondok Jati'), 'Transit ke Peron 5/6.');
  });

  test('Jakarta Kota — Jayakarta/Bogor to Kampung Bandan', () {
    expect(guide('Jayakarta', 'Jakarta Kota', 'Kampung Bandan'), 'Transit ke Jalur 8.');
    expect(guide('Bogor', 'Jakarta Kota', 'Kampung Bandan'), 'Transit ke Jalur 8.');
  });

  test('Jakarta Kota — Kampung Bandan/Priok to Jayakarta', () {
    expect(guide('Kampung Bandan', 'Jakarta Kota', 'Jayakarta'), 'Transit di Peron 9/10/11.');
    expect(guide('Tanjung Priok', 'Jakarta Kota', 'Jayakarta'), 'Transit di Peron 9/10/11.');
  });

  test('Kampung Bandan — Angke/Rajawali', () {
    expect(guide('Angke', 'Kampung Bandan', 'Jakarta Kota'), 'Transit ke Peron Atas 6.');
    expect(guide('Rajawali', 'Kampung Bandan', 'Jakarta Kota'), 'Transit ke Peron Atas 6.');
    expect(guide('Angke', 'Kampung Bandan', 'Ancol'), 'Transit ke Peron Atas 7.');
  });

  test('no rule matches falls back to null', () {
    expect(guide('Bogor', 'Manggarai', 'Bekasi'), isNull);
    expect(guide('Depok', 'Manggarai', 'Sudirman'), isNull);
    expect(guide('Bogor', 'Nambo', 'Cibinong'), isNull);
  });
}
