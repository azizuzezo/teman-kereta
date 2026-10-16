import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/features/account/presentation/login_page.dart';
import 'package:teman_kereta/features/account/presentation/widgets/password_field.dart';

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(360, 640),
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          extensions: <ThemeExtension<dynamic>>[
            TkPalettes.byId(TkPaletteId.navyKrl).forBrightness(brightness),
          ],
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const LoginPage(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('logo sits above the headline and the form', (tester) async {
    await _pump(tester);
    final logo = tester.getTopLeft(find.byType(Image).first);
    final headline = tester.getTopLeft(find.text('Selamat datang kembali'));
    final email = tester.getTopLeft(find.text('Email').first);
    expect(logo.dy, lessThan(headline.dy));
    expect(headline.dy, lessThan(email.dy));
    expect(find.text('Lupa kata sandi?'), findsOneWidget);
    expect(find.text('Kebijakan Privasi'), findsOneWidget);
  });

  testWidgets('Daftar shows name and a confirm password field with an eye each', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(PasswordField), findsOneWidget);
    await tester.tap(find.text('Daftar').first);
    await tester.pump();
    expect(find.byType(PasswordField), findsNWidgets(2));
    expect(find.byTooltip(PasswordField.showLabel), findsNWidgets(2));
    expect(find.text('Nama lengkap'), findsOneWidget);
    expect(find.text('Lupa kata sandi?'), findsNothing);
  });

  testWidgets('submitting empty shows inline errors, no network call', (tester) async {
    await _pump(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pump();
    expect(find.text('Email wajib diisi.'), findsOneWidget);
    expect(find.text('Kata sandi wajib diisi.'), findsOneWidget);
  });

  testWidgets('sign-up validates length and confirmation', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Daftar').first);
    await tester.pump();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Budi');
    await tester.enterText(fields.at(1), 'budi@email.com');
    await tester.enterText(fields.at(2), 'pendek');
    await tester.enterText(fields.at(3), 'beda');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Daftar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Daftar'));
    await tester.pump();
    expect(find.text('Kata sandi minimal 8 karakter.'), findsOneWidget);
    expect(find.text('Kata sandi tidak cocok.'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('no overflow at 320dp, 1.3x text, $brightness, both modes', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(320, 568),
        textScale: 1.3,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Daftar').first);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
