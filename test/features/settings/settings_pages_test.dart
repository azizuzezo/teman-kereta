import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/core/notifications/local_notification_service.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';
import 'package:teman_kereta/features/settings/presentation/accessibility_settings_page.dart';
import 'package:teman_kereta/features/settings/presentation/location_settings_page.dart';
import 'package:teman_kereta/features/settings/presentation/notification_settings_page.dart';
import 'package:teman_kereta/features/settings/presentation/permission_status.dart';
import 'package:teman_kereta/features/settings/presentation/settings_controller.dart';
import 'package:teman_kereta/features/settings/presentation/sound_test_page.dart';
import 'package:teman_kereta/features/settings/presentation/widgets/theme_switcher_card.dart';

import '../../support/fakes.dart';

/// Mirrors how `TemanKeretaApp` wires settings into `MaterialApp`, so a tap in
/// a settings page is checked against the real theme chain.
class _ThemedHarness extends ConsumerWidget {
  const _ThemedHarness({required this.home, this.textScale = 1.0});

  final Widget home;
  final double textScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return MaterialApp(
      theme: AppTheme.light(settings.palette),
      darkTheme: AppTheme.dark(settings.palette),
      themeMode: settings.themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget page, {
  double textScale = 1.0,
  Size size = const Size(360, 3000),
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = MemoryPreferencesStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [preferencesStoreProvider.overrideWithValue(store), ...overrides],
      child: _ThemedHarness(home: page, textScale: textScale),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
}

void main() {
  group('ThemeSwitcherCard drives the whole app theme', () {
    testWidgets('mode and palette taps change the live theme', (tester) async {
      final container = await _pump(
        tester,
        const Scaffold(body: SingleChildScrollView(child: ThemeSwitcherCard())),
      );
      BuildContext ctx() => tester.element(find.byType(ThemeSwitcherCard));

      expect(Theme.of(ctx()).brightness, Brightness.light);
      expect(ctx().tk.primary, TkPalettes.byId(TkPaletteId.navyKrl).light.primary);

      await tester.tap(find.text('Gelap'));
      await tester.pumpAndSettle();
      expect(Theme.of(ctx()).brightness, Brightness.dark);
      expect(container.read(settingsControllerProvider).themeMode, ThemeMode.dark);

      await tester.tap(find.text('Hijau Stasiun'));
      await tester.pumpAndSettle();
      expect(
        ctx().tk.primary,
        TkPalettes.byId(TkPaletteId.hijauStasiun).dark.primary,
      );
      expect(
        container.read(preferencesStoreProvider).snapshot.palette,
        TkPaletteId.hijauStasiun,
      );

      await tester.tap(find.text('Terang'));
      await tester.pumpAndSettle();
      expect(Theme.of(ctx()).brightness, Brightness.light);
      expect(
        ctx().tk.primary,
        TkPalettes.byId(TkPaletteId.hijauStasiun).light.primary,
      );
    });

    testWidgets('fits a 360dp screen at 1.3x text scale', (tester) async {
      await _pump(
        tester,
        const Scaffold(body: SingleChildScrollView(child: ThemeSwitcherCard())),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('notification settings', () {
    testWidgets('threshold choice updates the setting (no Radio widget)', (
      tester,
    ) async {
      final container = await _pump(tester, const NotificationSettingsPage());
      expect(find.byType(Radio<int>), findsNothing);
      expect(container.read(settingsControllerProvider).stopAlertThreshold, 3);

      await tester.tap(find.text('1 stasiun sebelum tujuan'));
      await tester.pumpAndSettle();
      expect(container.read(settingsControllerProvider).stopAlertThreshold, 1);
    });

    testWidgets('vibration and sound switches toggle their settings', (
      tester,
    ) async {
      final container = await _pump(tester, const NotificationSettingsPage());
      final before = container.read(settingsControllerProvider);

      await tester.tap(find.text('Getaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suara'));
      await tester.pumpAndSettle();

      final after = container.read(settingsControllerProvider);
      expect(after.vibrationEnabled, !before.vibrationEnabled);
      expect(after.soundEnabled, !before.soundEnabled);
    });

    testWidgets('survives 1.3x text scale', (tester) async {
      await _pump(tester, const NotificationSettingsPage(), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });

  group('accessibility settings', () {
    testWidgets('reduce motion and text scale reset work', (tester) async {
      final container = await _pump(tester, const AccessibilitySettingsPage());

      await tester.tap(find.text('Kurangi animasi'));
      await tester.pumpAndSettle();
      expect(container.read(settingsControllerProvider).reduceMotion, isTrue);

      await container.read(settingsControllerProvider.notifier).setTextScale(1.3);
      await tester.pumpAndSettle();
      expect(find.text('130%'), findsWidgets);
      await tester.tap(find.text('Kembalikan ke 100%'));
      await tester.pumpAndSettle();
      expect(container.read(settingsControllerProvider).textScale, 1.0);
    });

    testWidgets('survives 1.3x text scale', (tester) async {
      await _pump(tester, const AccessibilitySettingsPage(), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });

  group('location settings', () {
    testWidgets('lists every permission and keeps the ride detection switch', (
      tester,
    ) async {
      await _pump(
        tester,
        const LocationSettingsPage(),
        size: const Size(360, 4000),
        overrides: [
          devicePermissionStatusProvider.overrideWith(
            (ref) async => <String, Object?>{
              'foregroundLocation': true,
              'backgroundLocation': false,
              'activityRecognition': false,
              'batteryOptimizationIgnored': false,
              'manufacturer': 'xiaomi',
            },
          ),
        ],
      );

      expect(find.text('Lokasi saat digunakan'), findsOneWidget);
      expect(find.text('Lokasi latar belakang'), findsOneWidget);
      expect(find.text('Diizinkan'), findsOneWidget);
      expect(find.text('Deteksi otomatis naik KRL'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(
        find.text('Izinkan berjalan bebas di latar belakang'),
        findsOneWidget,
      );
      expect(find.text('Buka pengaturan khusus Xiaomi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives 1.3x text scale', (tester) async {
      await _pump(
        tester,
        const LocationSettingsPage(),
        textScale: 1.3,
        size: const Size(360, 5000),
        overrides: [
          devicePermissionStatusProvider.overrideWith(
            (ref) async => <String, Object?>{'foregroundLocation': true},
          ),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('sound test', () {
    testWidgets('plays an alert and warns when sound is off', (tester) async {
      final notifications = FakeNotificationService();
      final container = await _pump(
        tester,
        const SoundTestPage(),
        size: const Size(360, 4000),
        overrides: [
          localNotificationServiceProvider.overrideWithValue(notifications),
        ],
      );
      await container.read(settingsControllerProvider.notifier).setSoundEnabled(false);
      await tester.pumpAndSettle();
      expect(find.text('Suara notifikasi sedang dimatikan'), findsOneWidget);

      await tester.tap(find.text('3 stasiun lagi menuju tujuan'));
      await tester.pumpAndSettle();
      expect(notifications.stopAlerts, 1);

      await tester.tap(find.text('Nyalakan suara'));
      await tester.pumpAndSettle();
      expect(container.read(settingsControllerProvider).soundEnabled, isTrue);
      expect(find.text('Suara notifikasi sedang dimatikan'), findsNothing);
    });
  });
}
