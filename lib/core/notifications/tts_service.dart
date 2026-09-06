import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around `flutter_tts` for spoken voice alerts (transfer and
/// destination countdowns/arrivals). Initialization and every call are
/// best-effort: a device without Indonesian TTS data installed, or without
/// TTS at all, must never crash or block a trip-critical notification —
/// worst case is simply no voice, the silent/vibrate/sound notification
/// still fires regardless (see [LocalNotificationService]).
class TtsService {
  TtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }
    try {
      await _tts.setLanguage('id-ID');
    } on Object {
      // Fall back to whatever the platform's default TTS language is rather
      // than failing to speak at all.
    }
    _initialized = true;
  }

  Future<void> speak(String text) async {
    try {
      await initialize();
      await _tts.speak(text);
    } on Object {
      // Speech is a convenience layered on top of the real notification —
      // never let a TTS failure surface to the user or interrupt a trip.
    }
  }
}

final ttsServiceProvider = Provider<TtsService>((Ref ref) {
  return TtsService();
});
