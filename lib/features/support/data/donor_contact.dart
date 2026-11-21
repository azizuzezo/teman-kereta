import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config/app_environment.dart';

/// Kontak pendukung untuk QRIS yang mewajibkannya (Mayar): email diambil dari
/// akun yang sedang masuk, nomor HP diminta sekali lalu disimpan di akun itu
/// supaya donasi berikutnya tidak perlu mengisinya lagi.
abstract class DonorContactStore {
  /// Email akun yang sedang masuk; null bila belum masuk.
  String? get email;

  /// Nomor HP yang sudah tersimpan di akun; null bila belum pernah.
  String? get phone;

  Future<void> savePhone(String phone);
}

/// Nomor HP disimpan di `user_metadata.donor_phone` akun Supabase: ikut akun ke
/// perangkat lain, dan tidak perlu tabel atau migrasi baru.
class SupabaseDonorContactStore implements DonorContactStore {
  static const _phoneKey = 'donor_phone';

  User? get _user => Supabase.instance.client.auth.currentUser;

  @override
  String? get email {
    final value = _user?.email?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  String? get phone {
    final value = _user?.userMetadata?[_phoneKey];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  @override
  Future<void> savePhone(String phone) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: <String, Object?>{_phoneKey: phone}),
      );
    } on Object {
      // Gagal menyimpan tidak boleh menggagalkan donasi; nomor diminta lagi
      // di donasi berikutnya.
    }
  }
}

/// Tanpa akun (backend mati atau mode lokal): tidak ada yang tersimpan.
class NoDonorContactStore implements DonorContactStore {
  const NoDonorContactStore();

  @override
  String? get email => null;

  @override
  String? get phone => null;

  @override
  Future<void> savePhone(String phone) async {}
}

final donorContactStoreProvider = Provider<DonorContactStore>(
  (ref) => AppEnvironment.supabaseEnabled
      ? SupabaseDonorContactStore()
      : const NoDonorContactStore(),
);

final RegExp _phonePattern = RegExp(r'^\+?[0-9][0-9\s-]{7,16}$');

/// Sama dengan aturan di Patungan Yuk!: 8-17 karakter, boleh diawali `+`.
bool isValidDonorPhone(String value) => _phonePattern.hasMatch(value.trim());

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
bool isValidDonorEmail(String value) => _emailPattern.hasMatch(value.trim());
