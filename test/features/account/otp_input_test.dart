import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/features/account/presentation/widgets/otp_input.dart';

void main() {
  group('OtpDigitsFormatter', () {
    const formatter = OtpDigitsFormatter(6);
    TextEditingValue run(String text) => formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: text),
    );

    test('strips separators from a pasted code', () {
      expect(run('123 456').text, '123456');
      expect(run('123-456').text, '123456');
    });
    test('cuts to the code length', () {
      expect(run('12345678').text, '123456');
    });
    test('drops letters', () {
      expect(run('1a2b3').text, '123');
    });
  });

  group('OtpInput', () {
    Future<List<String>> pump(
      WidgetTester tester,
      TextEditingController c, {
      bool hasError = false,
    }) async {
      final completed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: OtpInput(
                controller: c,
                hasError: hasError,
                onCompleted: completed.add,
              ),
            ),
          ),
        ),
      );
      return completed;
    }

    testWidgets('draws typed digits and completes on the sixth', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      final completed = await pump(tester, c);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(completed, isEmpty);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      expect(completed, <String>['123456']);
    });

    testWidgets('a pasted code with spaces completes too', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      final completed = await pump(tester, c);

      await tester.enterText(find.byType(TextField), '654 321');
      await tester.pump();
      expect(c.text, '654321');
      expect(completed, <String>['654321']);
    });

    testWidgets('asks the OS for one time code autofill', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await pump(tester, c);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
      expect(field.keyboardType, TextInputType.number);
    });

    testWidgets('fits a 320dp wide screen at 1.3x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = TextEditingController(text: '123456');
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: OtpInput(controller: c, hasError: true),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
