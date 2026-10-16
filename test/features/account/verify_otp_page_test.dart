import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/features/account/presentation/account_controller.dart';
import 'package:teman_kereta/features/account/presentation/auth_errors.dart';
import 'package:teman_kereta/features/account/presentation/verify_otp_page.dart';

class _FakeAccount extends AccountController {
  _FakeAccount({this.verifyError});

  final String? verifyError;
  final List<String> verified = <String>[];
  int resent = 0;

  @override
  Future<String?> verifySignupOtp({
    required String email,
    required String code,
  }) async {
    verified.add(code);
    return verifyError;
  }

  @override
  Future<String?> resendSignupOtp({required String email}) async {
    resent += 1;
    OtpCooldown.markSent(email);
    return null;
  }
}

Future<void> _pump(WidgetTester tester, _FakeAccount fake) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accountControllerProvider.overrideWith(() => fake)],
      child: const MaterialApp(
        home: VerifyOtpPage(email: 'azizuzezo@gmail.com'),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(OtpCooldown.reset);

  testWidgets('shows the masked address, never the full one', (tester) async {
    OtpCooldown.markSent('azizuzezo@gmail.com');
    await _pump(tester, _FakeAccount());
    expect(find.textContaining('az***@gmail.com'), findsOneWidget);
    expect(find.textContaining('azizuzezo@gmail.com'), findsNothing);
    expect(find.text('Ganti email'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('wrong code shows the error and clears the boxes', (tester) async {
    OtpCooldown.markSent('azizuzezo@gmail.com');
    final fake = _FakeAccount(verifyError: 'Kode salah atau sudah kedaluwarsa.');
    await _pump(tester, fake);

    await tester.enterText(find.byType(TextField), '111111');
    await tester.pump();
    await tester.pump();

    expect(fake.verified, <String>['111111']);
    expect(find.text('Kode salah atau sudah kedaluwarsa.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('does not submit before six digits', (tester) async {
    OtpCooldown.markSent('azizuzezo@gmail.com');
    final fake = _FakeAccount();
    await _pump(tester, fake);
    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();
    expect(fake.verified, isEmpty);
    await tester.tap(find.text('Verifikasi'));
    await tester.pump();
    expect(fake.verified, isEmpty);
    expect(find.textContaining('6 digit'), findsWidgets);
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('resend is locked for 60 seconds with a visible countdown', (
    tester,
  ) async {
    OtpCooldown.markSent('azizuzezo@gmail.com');
    final fake = _FakeAccount();
    await _pump(tester, fake);

    expect(find.textContaining('Kirim ulang dalam 1:0'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Kirim ulang dalam 0:5'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    expect(find.text('Kirim ulang kode'), findsOneWidget);
    await tester.tap(find.text('Kirim ulang kode'));
    await tester.pump();
    await tester.pump();
    expect(fake.resent, 1);
    expect(find.textContaining('Kirim ulang dalam'), findsOneWidget);
    expect(find.text('Kode baru sudah dikirim. Cek emailmu.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
  });
}
