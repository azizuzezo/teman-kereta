import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/diagnostics/log_redactor.dart';

void main() {
  group('redactSecrets', () {
    test('masks JWTs including the Supabase anon key shape', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSJ9.o-N_03nF0ZmlurmHM3_ogRDupnXLOPY2ztAU8zU0kbE';
      final out = redactSecrets('session token $jwt refreshed');
      expect(out, 'session token [JWT] refreshed');
      expect(out, isNot(contains('eyJ')));
    });

    test('masks bearer tokens case-insensitively', () {
      expect(
        redactSecrets('Authorization header: bearer abc123DEF456ghi789'),
        isNot(contains('abc123DEF456ghi789')),
      );
      expect(redactSecrets('Bearer abcdefgh12345678'), 'Bearer [TOKEN]');
    });

    test('masks key=value, key: value and JSON secrets, keeps the key', () {
      expect(redactSecrets('apikey=sb_publishable_xyz123'), 'apikey=[REDACTED]');
      expect(redactSecrets('password: hunter2 failed'), 'password: [REDACTED] failed');
      expect(
        redactSecrets('{"access_token":"abc.def","other":"ok"}'),
        '{"access_token":"[REDACTED]","other":"ok"}',
      );
      expect(
        redactSecrets('url?token=s3cr3t&x=1'),
        'url?token=[REDACTED]&x=1',
      );
    });

    test('masks e-mail addresses', () {
      expect(
        redactSecrets('login failed for budi.santoso+krl@gmail.co.id today'),
        'login failed for [EMAIL] today',
      );
    });

    test('masks Indonesian and international phone numbers', () {
      expect(redactSecrets('call 081234567890 now'), 'call [PHONE] now');
      expect(redactSecrets('wa +62 812-3456-7890'), 'wa [PHONE]');
      expect(redactSecrets('wa 6281234567890.'), contains('[PHONE]'));
      expect(redactSecrets('tel +1 415 555 2671'), contains('[PHONE]'));
    });

    test('leaves timestamps, uuids, versions and counts alone', () {
      const safe =
          '2026-10-15T10:22:11.034+07:00 I [Trip] id=3f2b8c1e-7a4d-4e0a-9b1f-2c5d6e7f8a90 v1.0.17+18 stops=12 delay=240s';
      expect(redactSecrets(safe), safe);
    });

    test('coarsens coordinates to 2 decimals instead of removing them', () {
      expect(
        redactSecrets('fix -6.2088123, 106.8455678 acc=12'),
        'fix -6.21,106.85~ acc=12',
      );
      expect(redactSecrets('speed 12.34567'), 'speed 12.34567');
    });

    test('handles empty input and several secrets in one line', () {
      expect(redactSecrets(''), '');
      final out = redactSecrets(
        'user a@b.com token=zzz1234 phone 08123456789',
      );
      expect(out, 'user [EMAIL] token=[REDACTED] phone [PHONE]');
    });
  });
}
