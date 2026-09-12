import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// No audio focus requested at all: this alarm is a supplementary cue
/// layered on top of everything else already sounding (the spoken
/// notification, a later alert's own voice/alarm, whatever the rider is
/// listening to) and must never grab exclusive focus. Requesting
/// [AndroidAudioFocus.gain] (the package default) reproduced a bug where
/// stopping the alarm mid-playback left focus stuck, silencing the very
/// next notification's sound.
final _audioContext = AudioContext(
  android: const AudioContextAndroid(
    audioFocus: AndroidAudioFocus.none,
    contentType: AndroidContentType.sonification,
    usageType: AndroidUsageType.alarm,
  ),
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.playback,
    options: const {AVAudioSessionOptions.mixWithOthers},
  ),
);

/// Plays the bundled `assets/alarm.mp3` cue right after a spoken reminder
/// finishes (see [LocalNotificationService]) — a louder, harder-to-miss
/// follow-up for the "1 stasiun lagi" transfer/arrival alerts. Best-effort
/// like [TtsService.speak]: playback failing must never crash or block a
/// trip-critical notification.
class AlarmService {
  AlarmService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  Future<void> play() async {
    try {
      await _player.setAudioContext(_audioContext);
      await _player.stop();
      await _player.play(AssetSource('alarm.mp3'));
    } on Object {
      // See rationale above — never let this surface to the user.
    }
  }

  /// Silences the alarm once the rider has noticed it — tapping the alert
  /// notification or its "Matikan alarm" action (see
  /// [LocalNotificationService]) both call this. A no-op, not an error, if
  /// nothing is playing.
  Future<void> stop() async {
    try {
      await _player.stop();
    } on Object {
      // See rationale above.
    }
  }
}

final alarmServiceProvider = Provider<AlarmService>((Ref ref) {
  return AlarmService();
});
