import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/utils/ride_hailing_launcher.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// A fake platform implementation so [RideHailingLauncher] can be tested
/// without ever needing Gojek/Grab actually installed — [canLaunch] is
/// scripted per test to simulate "app installed" vs "app not installed",
/// and every [launch]/[launchUrl] call is recorded for assertions.
class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final List<String> canLaunchCalls = <String>[];
  final List<String> launchCalls = <String>[];
  bool canLaunchResult = false;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async {
    canLaunchCalls.add(url);
    return canLaunchResult;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchCalls.add(url);
    return true;
  }
}

void main() {
  late _FakeUrlLauncherPlatform fakePlatform;

  setUp(() {
    fakePlatform = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakePlatform;
  });

  test('opens the Gojek app scheme directly when it is installed', () async {
    fakePlatform.canLaunchResult = true;

    await const RideHailingLauncher().open(RideHailingApp.gojek);

    expect(fakePlatform.canLaunchCalls, <String>['gojek://']);
    expect(fakePlatform.launchCalls, <String>['gojek://']);
  });

  test('falls back to the Play Store listing when Gojek is not installed', () async {
    fakePlatform.canLaunchResult = false;

    await const RideHailingLauncher().open(RideHailingApp.gojek);

    expect(fakePlatform.canLaunchCalls, <String>['gojek://']);
    expect(fakePlatform.launchCalls, <String>[
      'https://play.google.com/store/apps/details?id=com.gojek.app',
    ]);
  });

  test('falls back to the Play Store listing when Grab is not installed', () async {
    fakePlatform.canLaunchResult = false;

    await const RideHailingLauncher().open(RideHailingApp.grab);

    expect(fakePlatform.canLaunchCalls, <String>['grab://open']);
    expect(fakePlatform.launchCalls, <String>[
      'https://play.google.com/store/apps/details?id=com.grabtaxi.passenger',
    ]);
  });
}
