import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/data/providers/supabase_transit_provider.dart';

void main() {
  group('parseScheduleWindow', () {
    test('membaca satu baris jendela dari RPC', () {
      final window = parseScheduleWindow(<Map<String, Object?>>[
        <String, Object?>{
          'first_date': '2026-12-01',
          'last_date': '2026-12-27',
          'schedule_set': 'gapeka2026',
        },
      ]);
      expect(window, isNotNull);
      expect(window!.start, DateTime.parse('2026-12-01'));
      expect(window.end, DateTime.parse('2026-12-27'));
    });

    test('set aktif tanpa perjalanan (tanggal null) jatuh ke cara lama', () {
      expect(
        parseScheduleWindow(<Map<String, Object?>>[
          <String, Object?>{
            'first_date': null,
            'last_date': null,
            'schedule_set': 'gapeka2026',
          },
        ]),
        isNull,
      );
    });

    test('jawaban kosong atau aneh tidak membuat error', () {
      expect(parseScheduleWindow(<Object?>[]), isNull);
      expect(parseScheduleWindow(null), isNull);
      expect(parseScheduleWindow('x'), isNull);
      expect(parseScheduleWindow(<Object?>['x']), isNull);
      expect(
        parseScheduleWindow(<Map<String, Object?>>[
          <String, Object?>{'first_date': 'bukan-tanggal', 'last_date': '2026-12-27'},
        ]),
        isNull,
      );
    });

    test('jendela dari set baru dipakai untuk menggeser hari ini', () {
      final window = parseScheduleWindow(<Map<String, Object?>>[
        <String, Object?>{'first_date': '2026-12-01', 'last_date': '2026-12-27'},
      ])!;
      // Sebelum jendela mulai: digeser mundur tepat kelipatan 7 hari ke dalam jendela.
      final shift = weekdayAlignedShift(
        DateTime(2026, 11, 28, 10),
        window.start,
        window.end,
      );
      expect(shift, isNotNull);
      expect(shift!.inDays % 7, 0);
      expect(shift.isNegative, isTrue);
    });
  });
}
