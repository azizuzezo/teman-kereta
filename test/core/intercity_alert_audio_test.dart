import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/notifications/alert_audio_plan.dart';

void main() {
  group('intercity distance reminders', () {
    test('are announced at 30, 15 and 10 km, and only the last has the bell', () {
      expect(intercityReminderKm, <int>[30, 15, 10]);
      expect(bellFollowsIntercityVoice(30), isFalse);
      expect(bellFollowsIntercityVoice(15), isFalse);
      expect(bellFollowsIntercityVoice(10), isTrue);
    });

    test('every reminder has its recorded clip, shipped on both platforms', () {
      final keep = File('android/app/src/main/res/raw/keep.xml').readAsStringSync();
      for (final km in intercityReminderKm) {
        final voice = intercityKmVoice(km);
        expect(voice, 'eta_km_$km');
        expect(File('android/app/src/main/res/raw/$voice.wav').existsSync(), isTrue,
            reason: 'Android clip for $km km');
        expect(File('ios/Runner/Sounds/$voice.wav').existsSync(), isTrue,
            reason: 'iOS clip for $km km');
        // Release builds strip a raw resource nothing references in code.
        expect(keep, contains('@raw/$voice'), reason: '$voice must be kept in keep.xml');
      }
    });

    test('a distance with no clip falls back to the text-to-speech', () {
      expect(intercityKmVoice(5), isNull);
    });
  });
}
