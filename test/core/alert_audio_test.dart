import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/notifications/alert_audio_plan.dart';
import 'package:teman_kereta/core/platform/native_trip_service.dart';

const _channel = MethodChannel('id.temankereta.teman_kereta/native');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('alert audio plan', () {
    test('stop alerts use the matching recorded voice, none beyond 3 stops', () {
      expect(stopAlertVoice(0), 'arrive_station');
      expect(stopAlertVoice(1), 'remaining_station_1');
      expect(stopAlertVoice(2), 'remaining_station_2');
      expect(stopAlertVoice(3), 'remaining_station_3');
      expect(stopAlertVoice(4), isNull);
      expect(stopAlertVoice(-1), isNull);
    });

    test('transfer countdown voices exist for 1..3 stops only', () {
      expect(transferApproachingVoice(0), isNull);
      expect(transferApproachingVoice(1), 'remaining_transit_1');
      expect(transferApproachingVoice(3), 'remaining_transit_3');
      expect(transferApproachingVoice(4), isNull);
    });

    test('the bell follows only the 1-stop announcement', () {
      expect(bellFollowsVoice(1), isTrue);
      for (final n in [0, 2, 3, 4]) {
        expect(bellFollowsVoice(n), isFalse, reason: '$n stops');
      }
    });

    test('voiced alerts get a silent v2 channel, others the generic one', () {
      expect(alertChannelId('remaining_station_1'), 'tk_alert_remaining_station_1');
      expect(alertChannelId(arrivalVoice), 'tk_alert_arrive_station');
      expect(alertChannelId(null), genericAlertChannelId);
    });

    test('no new channel id collides with a retired one', () {
      final voices = <String?>[
        for (var n = 0; n <= 4; n++) stopAlertVoice(n),
        for (var n = 0; n <= 4; n++) transferApproachingVoice(n),
        transferReminderVoice,
        missedDestinationVoice,
      ];
      for (final voice in voices) {
        expect(retiredAlertChannelIds, isNot(contains(alertChannelId(voice))));
      }
    });
  });

  group('AudioRouteInfo', () {
    test('a headset snapshot is parsed with its kind and name', () {
      final info = AudioRouteInfo.fromNative(<String, Object?>{
        'route': 'headset',
        'deviceKind': 'bluetooth',
        'deviceName': ' Buds ',
      });
      expect(info.isHeadset, isTrue);
      expect(info.deviceKind, 'bluetooth');
      expect(info.deviceName, 'Buds');
      expect(info.statusText, 'Tersambung ke headset (Buds)');
    });

    test('a headset with no name still reads as connected', () {
      final info = AudioRouteInfo.fromNative(<String, Object?>{
        'route': 'headset',
        'deviceName': '  ',
      });
      expect(info.isHeadset, isTrue);
      expect(info.deviceName, isNull);
      expect(info.statusText, 'Tersambung ke headset');
    });

    test('anything unreadable falls back to the speaker', () {
      expect(AudioRouteInfo.fromNative(null), AudioRouteInfo.speaker);
      expect(
        AudioRouteInfo.fromNative(<String, Object?>{'route': 'speaker'}),
        AudioRouteInfo.speaker,
      );
      expect(
        AudioRouteInfo.fromNative(<String, Object?>{'route': 42}),
        AudioRouteInfo.speaker,
      );
      expect(AudioRouteInfo.speaker.statusText, 'Suara lewat speaker ponsel');
    });
  });

  group('NativeTripService audio', () {
    final calls = <MethodCall>[];

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
      calls.clear();
    });

    void mock(Future<Object?>? Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            return handler(call);
          });
    }

    test('audioRoute reports the headset native sees', () async {
      mock((call) async => <String, Object?>{
        'route': 'headset',
        'deviceKind': 'wired',
        'deviceName': null,
      });
      final info = await const NativeTripService().audioRoute();
      expect(calls.single.method, 'getAudioRoute');
      expect(info.route, AudioRoute.headset);
      expect(info.deviceKind, 'wired');
    });

    test('audioRoute is the speaker without a native side', () async {
      // No handler registered: MissingPluginException, as in any unit test.
      expect(await const NativeTripService().audioRoute(), AudioRouteInfo.speaker);
    });

    test('playAlertAudio sends the voice and bell flag', () async {
      mock((call) async => null);
      await const NativeTripService().playAlertAudio(
        voice: 'remaining_station_1',
        bell: true,
      );
      expect(calls.single.method, 'playAlertAudio');
      expect(calls.single.arguments, <String, Object?>{
        'voice': 'remaining_station_1',
        'bell': true,
      });
    });

    test('playAlertAudio with nothing to play makes no native call', () async {
      mock((call) async => null);
      await const NativeTripService().playAlertAudio();
      expect(calls, isEmpty);
    });

    test('silenceAlertBell and stopAlertAudio reach native', () async {
      mock((call) async => null);
      await const NativeTripService().silenceAlertBell();
      await const NativeTripService().stopAlertAudio();
      expect(calls.map((c) => c.method), ['silenceAlertBell', 'stopAlertAudio']);
    });
  });
}
