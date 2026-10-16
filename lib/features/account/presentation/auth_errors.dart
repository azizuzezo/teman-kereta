import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Shortest password the app accepts when a password is *created* (sign-up and
/// reset). Matches `minimum_password_length` in `supabase/config.toml`.
/// Sign-in never enforces it, so accounts made with the old 6 character
/// minimum can still log in.
const kMinPasswordLength = 8;

/// Length of the email verification code (`otp_length` in `config.toml`).
const kOtpLength = 6;

/// Which backend call failed. Changes how the same server error reads.
enum AuthFlow { signIn, signUp, verifyOtp, resendOtp, resetPassword }

class AuthFailure {
  const AuthFailure(
    this.message, {
    this.needsVerification = false,
    this.alreadyRegistered = false,
    this.rateLimited = false,
    this.offline = false,
  });

  final String message;

  /// Sign-in refused because the email was never verified.
  final bool needsVerification;

  /// Sign-up for an email that already has an account.
  final bool alreadyRegistered;
  final bool rateLimited;
  final bool offline;
}

const _offlineMessage =
    'Tidak ada koneksi internet. Periksa jaringanmu lalu coba lagi.';

bool _looksOffline(Object error) {
  if (error is SocketException || error is TimeoutException) return true;
  if (error is AuthRetryableFetchException) return true;
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Network is unreachable') ||
      text.contains('Connection refused');
}

/// Turns any error thrown by Supabase Auth into one Indonesian sentence the
/// user can act on. Pure, so every branch is unit-tested.
AuthFailure mapAuthError(Object error, AuthFlow flow) {
  if (_looksOffline(error)) {
    return const AuthFailure(_offlineMessage, offline: true);
  }

  if (error is AuthException) {
    final code = (error.code ?? '').toLowerCase();
    final message = error.message.toLowerCase();
    final status = error.statusCode;

    final rateLimited =
        code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        status == '429' ||
        message.contains('rate limit') ||
        message.contains('for security purposes');
    if (rateLimited) {
      return AuthFailure(
        flow == AuthFlow.verifyOtp
            ? 'Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi.'
            : 'Terlalu sering meminta email. Tunggu sebentar lalu coba lagi.',
        rateLimited: true,
      );
    }

    if (code == 'email_not_confirmed' || message.contains('not confirmed')) {
      return const AuthFailure(
        'Email ini belum diverifikasi. Masukkan kode yang kami kirim ke emailmu.',
        needsVerification: true,
      );
    }

    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        message.contains('already registered') ||
        message.contains('already been registered')) {
      return const AuthFailure(
        'Email ini sudah terdaftar. Coba masuk, atau pakai Lupa kata sandi.',
        alreadyRegistered: true,
      );
    }

    if (code == 'weak_password' || error is AuthWeakPasswordException) {
      return const AuthFailure(
        'Kata sandi terlalu mudah ditebak. Tambah panjang atau campur huruf dan angka.',
      );
    }

    if (code == 'otp_expired' ||
        (flow == AuthFlow.verifyOtp &&
            (message.contains('expired') || message.contains('invalid')))) {
      return const AuthFailure(
        'Kode salah atau sudah kedaluwarsa. Periksa lagi, atau kirim ulang kode baru.',
      );
    }

    if (code == 'invalid_credentials' || message.contains('invalid login')) {
      return const AuthFailure('Email atau kata sandi salah. Coba lagi.');
    }

    if (code == 'email_address_invalid' || code == 'validation_failed') {
      return const AuthFailure('Format email belum benar. Periksa lagi.');
    }

    if (code == 'signup_disabled') {
      return const AuthFailure('Pendaftaran akun baru sedang ditutup.');
    }
  }

  return AuthFailure(switch (flow) {
    AuthFlow.signIn => 'Gagal masuk. Coba lagi sebentar lagi.',
    AuthFlow.signUp => 'Pendaftaran gagal. Coba lagi sebentar lagi.',
    AuthFlow.verifyOtp => 'Verifikasi gagal. Coba lagi sebentar lagi.',
    AuthFlow.resendOtp => 'Gagal mengirim ulang kode. Coba lagi sebentar lagi.',
    AuthFlow.resetPassword =>
      'Gagal mengirim email reset. Coba lagi sebentar lagi.',
  });
}

/// `azizuzezo@gmail.com` becomes `az***@gmail.com`. Keeps enough of the
/// address to recognise it while the screen stays safe to show over a shoulder.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  final local = email.substring(0, at);
  final domain = email.substring(at);
  final keep = local.length <= 2 ? 1 : 2;
  return '${local.substring(0, keep)}***$domain';
}

String? validateEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Email wajib diisi.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(text)) {
    return 'Masukkan email yang valid, misalnya nama@email.com.';
  }
  return null;
}

String? validateNewPassword(String? value) {
  final text = value ?? '';
  if (text.isEmpty) return 'Kata sandi wajib diisi.';
  if (text.length < kMinPasswordLength) {
    return 'Kata sandi minimal $kMinPasswordLength karakter.';
  }
  return null;
}

String? validateCurrentPassword(String? value) {
  if (value == null || value.isEmpty) return 'Kata sandi wajib diisi.';
  return null;
}

String? validatePasswordMatch(String? value, String original) {
  if (value == null || value.isEmpty) return 'Ulangi kata sandi.';
  if (value != original) return 'Kata sandi tidak cocok.';
  return null;
}

/// Remembers when a verification email was last sent so the 60 second resend
/// cooldown survives leaving and re-entering the verification screen (the
/// server enforces the same limit, see `max_frequency` in `config.toml`).
class OtpCooldown {
  OtpCooldown._();

  static const int seconds = 60;
  static final Map<String, DateTime> _sentAt = <String, DateTime>{};

  static String _key(String email) => email.trim().toLowerCase();

  static void markSent(String email, {DateTime? now}) {
    _sentAt[_key(email)] = now ?? DateTime.now();
  }

  /// Seconds left before another email may be requested, 0 when allowed.
  static int remaining(String email, {DateTime? now}) {
    final sent = _sentAt[_key(email)];
    if (sent == null) return 0;
    final elapsed = (now ?? DateTime.now()).difference(sent).inSeconds;
    return (seconds - elapsed).clamp(0, seconds);
  }

  static void reset() => _sentAt.clear();
}

/// `75` becomes `1:15`.
String formatCountdown(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
