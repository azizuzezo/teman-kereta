import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teman_kereta/features/account/presentation/auth_errors.dart';

void main() {
  group('mapAuthError', () {
    test('offline errors win over everything else', () {
      for (final error in <Object>[
        const SocketException('Failed host lookup'),
        TimeoutException('slow'),
        AuthRetryableFetchException(message: 'x'),
      ]) {
        final failure = mapAuthError(error, AuthFlow.verifyOtp);
        expect(failure.offline, isTrue);
        expect(failure.message, contains('koneksi'));
      }
    });

    test('wrong or expired code reads as one clear message', () {
      final failure = mapAuthError(
        const AuthApiException(
          'Token has expired or is invalid',
          statusCode: '403',
          code: 'otp_expired',
        ),
        AuthFlow.verifyOtp,
      );
      expect(failure.message, contains('salah atau sudah kedaluwarsa'));
      expect(failure.rateLimited, isFalse);
    });

    test('rate limit is flagged and worded per flow', () {
      const error = AuthApiException(
        'rate limit',
        statusCode: '429',
        code: 'over_email_send_rate_limit',
      );
      final verify = mapAuthError(error, AuthFlow.verifyOtp);
      final resend = mapAuthError(error, AuthFlow.resendOtp);
      expect(verify.rateLimited, isTrue);
      expect(verify.message, contains('Terlalu banyak percobaan'));
      expect(resend.message, contains('Terlalu sering'));
    });

    test('unverified account on sign-in asks for verification', () {
      final failure = mapAuthError(
        const AuthApiException(
          'Email not confirmed',
          statusCode: '400',
          code: 'email_not_confirmed',
        ),
        AuthFlow.signIn,
      );
      expect(failure.needsVerification, isTrue);
    });

    test('already registered email is flagged', () {
      final failure = mapAuthError(
        const AuthApiException(
          'User already registered',
          statusCode: '422',
          code: 'user_already_exists',
        ),
        AuthFlow.signUp,
      );
      expect(failure.alreadyRegistered, isTrue);
    });

    test('bad credentials and unknown errors differ', () {
      final bad = mapAuthError(
        const AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
        AuthFlow.signIn,
      );
      expect(bad.message, contains('Email atau kata sandi salah'));
      final unknown = mapAuthError(StateError('boom'), AuthFlow.signIn);
      expect(unknown.message, contains('Gagal masuk'));
      expect(unknown.needsVerification, isFalse);
    });
  });

  group('maskEmail', () {
    test('keeps two characters and the domain', () {
      expect(maskEmail('azizuzezo@gmail.com'), 'az***@gmail.com');
    });
    test('short local part keeps one character', () {
      expect(maskEmail('ab@x.id'), 'a***@x.id');
    });
    test('non email is returned as is', () {
      expect(maskEmail('bukan-email'), 'bukan-email');
    });
  });

  group('validators', () {
    test('email', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('abc'), isNotNull);
      expect(validateEmail('a@b'), isNotNull);
      expect(validateEmail(' nama@email.com '), isNull);
    });
    test('new password needs the minimum length', () {
      expect(validateNewPassword('1234567'), isNotNull);
      expect(validateNewPassword('12345678'), isNull);
    });
    test('current password only needs to be present', () {
      expect(validateCurrentPassword('123456'), isNull);
      expect(validateCurrentPassword(''), isNotNull);
    });
    test('confirmation must match', () {
      expect(validatePasswordMatch('', 'abc12345'), isNotNull);
      expect(validatePasswordMatch('abc1234', 'abc12345'), isNotNull);
      expect(validatePasswordMatch('abc12345', 'abc12345'), isNull);
    });
  });

  group('OtpCooldown', () {
    setUp(OtpCooldown.reset);

    test('counts down and is case-insensitive on the address', () {
      final t0 = DateTime(2026, 1, 1, 10);
      OtpCooldown.markSent('Nama@Email.com', now: t0);
      expect(OtpCooldown.remaining('nama@email.com', now: t0), 60);
      expect(
        OtpCooldown.remaining(
          'nama@email.com',
          now: t0.add(const Duration(seconds: 45)),
        ),
        15,
      );
      expect(
        OtpCooldown.remaining(
          'nama@email.com',
          now: t0.add(const Duration(seconds: 90)),
        ),
        0,
      );
    });

    test('unknown address is not on cooldown', () {
      expect(OtpCooldown.remaining('x@y.id'), 0);
    });
  });

  test('formatCountdown', () {
    expect(formatCountdown(60), '1:00');
    expect(formatCountdown(9), '0:09');
  });
}
