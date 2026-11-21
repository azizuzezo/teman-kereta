import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// QRIS dukungan untuk pengembang, dibuat oleh Patungan Yuk! (patungan.gifts).
class DevDonationQris {
  const DevDonationQris({
    required this.trxId,
    required this.amount,
    required this.baseAmount,
    required this.fee,
    required this.expiresAt,
    required this.qrisCode,
    required this.qrImageUrl,
  });

  final String trxId;

  /// Yang harus dibayar, sudah termasuk biaya QRIS dan kode unik.
  final int amount;

  /// Nominal yang dipilih pendukung.
  final int baseAmount;
  final int fee;
  final DateTime? expiresAt;

  /// Isi QR (EMV) untuk digambar di aplikasi; null bila gateway tidak
  /// memberikannya, lalu dipakai [qrImageUrl].
  final String? qrisCode;
  final String qrImageUrl;

  /// Selisih terhadap [baseAmount] yang bukan biaya: kode unik supaya
  /// pembayaran terdeteksi otomatis.
  int get uniqueCode => (amount - baseAmount - fee).clamp(0, amount);
}

/// Pengaturan QRIS dukungan yang berlaku sekarang di Patungan Yuk!. Pemilik
/// mengubahnya di Patungan (GoPay atau Mayar); aplikasi membacanya berulang
/// supaya formnya ikut berubah.
class DevDonationConfig {
  const DevDonationConfig({
    required this.provider,
    required this.requiresEmail,
    required this.requiresPhone,
    required this.minAmount,
  });

  /// Dipakai bila belum ada jawaban dari server: GoPay, tanpa kontak wajib.
  static const DevDonationConfig fallback = DevDonationConfig(
    provider: 'gopay',
    requiresEmail: false,
    requiresPhone: false,
    minAmount: 0,
  );

  final String provider;
  final bool requiresEmail;
  final bool requiresPhone;
  final int minAmount;

  @override
  bool operator ==(Object other) =>
      other is DevDonationConfig &&
      other.provider == provider &&
      other.requiresEmail == requiresEmail &&
      other.requiresPhone == requiresPhone &&
      other.minAmount == minAmount;

  @override
  int get hashCode =>
      Object.hash(provider, requiresEmail, requiresPhone, minAmount);
}

enum DevDonationState { pending, paid, expired, unknown }

class DevDonationStatus {
  const DevDonationStatus(this.state, {this.serverNow});

  final DevDonationState state;

  /// Jam server saat status dibaca, untuk hitung mundur yang tidak bergantung
  /// jam HP.
  final DateTime? serverNow;
}

/// Gagal membuat QRIS. [minimum] terisi bila nominalnya di bawah batas.
class DevDonationException implements Exception {
  const DevDonationException(
    this.message, {
    this.minimum,
    this.retryable = true,
    this.needsEmail = false,
    this.needsPhone = false,
  });

  final String message;
  final int? minimum;
  final bool retryable;

  /// QRIS yang aktif mewajibkan kontak yang belum dikirim (Mayar).
  final bool needsEmail;
  final bool needsPhone;

  bool get needsContact => needsEmail || needsPhone;

  @override
  String toString() => 'DevDonationException($message)';
}

/// Alamat Patungan Yuk!. Bisa diganti saat uji dengan
/// `--dart-define=PATUNGAN_BASE_URL=http://...`.
const String _defaultBaseUrl = String.fromEnvironment(
  'PATUNGAN_BASE_URL',
  defaultValue: 'https://patungan.gifts',
);

class DevDonationApi {
  DevDonationApi({Dio? dio, this.baseUrl = _defaultBaseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: const <String, Object>{'Accept': 'application/json'},
            ),
          );

  final Dio _dio;
  final String baseUrl;

  /// Pengaturan QRIS yang berlaku untuk [amount]. Melempar bila server tidak
  /// terjangkau, sehingga pemanggil bisa menandai "offline".
  Future<DevDonationConfig> config({int? amount}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/app/dev-donation/config',
        queryParameters: <String, Object?>{
          if (amount != null && amount > 0) 'amount': amount,
        },
      );
      final data = response.data;
      if (data == null || data['provider'] is! String) {
        throw const DevDonationException('Jawaban server tidak lengkap.');
      }
      return DevDonationConfig(
        provider: data['provider'] as String,
        requiresEmail: data['requiresEmail'] == true,
        requiresPhone: data['requiresPhone'] == true,
        minAmount: (data['minAmount'] as num?)?.toInt() ?? 0,
      );
    } on DioException {
      throw const DevDonationException('Server pembayaran tidak terjangkau.');
    }
  }

  Future<DevDonationQris> create({
    required int amount,
    String? name,
    String? message,
    String? email,
    String? phone,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/app/dev-donation',
        data: <String, Object?>{
          'amount': amount,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          if (message != null && message.trim().isNotEmpty)
            'message': message.trim(),
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        },
      );
      final data = response.data;
      if (data == null) {
        throw const DevDonationException('Jawaban kosong dari server.');
      }
      return _parse(data);
    } on DioException catch (e) {
      final body = e.response?.data;
      if (e.response?.statusCode == 400 && body is Map && body['min'] is num) {
        final minimum = (body['min'] as num).toInt();
        throw DevDonationException(
          'Nominal minimal Rp$minimum.',
          minimum: minimum,
          retryable: false,
        );
      }
      if (e.response?.statusCode == 422 &&
          body is Map &&
          body['error'] == 'contact_required') {
        final needs = body['needs'];
        throw DevDonationException(
          'Lengkapi data kontak dulu.',
          needsEmail: needs is Map && needs['email'] == true,
          needsPhone: needs is Map && needs['phone'] == true,
        );
      }
      if (e.response?.statusCode == 400 && body is Map) {
        final field = body['error'];
        if (field == 'phone') {
          throw const DevDonationException(
            'Nomor HP belum benar, contoh: 08123456789.',
            retryable: false,
          );
        }
        if (field == 'email') {
          throw const DevDonationException(
            'Alamat email belum benar.',
            retryable: false,
          );
        }
      }
      throw const DevDonationException(
        'QRIS belum bisa dibuat. Coba lagi sebentar.',
      );
    }
  }

  DevDonationQris _parse(Map<String, dynamic> data) {
    final trxId = data['trxId'] as String?;
    final amount = (data['amount'] as num?)?.toInt();
    final path = data['qrImagePath'] as String?;
    if (trxId == null || amount == null || path == null) {
      throw const DevDonationException('Jawaban server tidak lengkap.');
    }
    final expires = data['expiresAt'];
    return DevDonationQris(
      trxId: trxId,
      amount: amount,
      baseAmount: (data['baseAmount'] as num?)?.toInt() ?? amount,
      fee: (data['fee'] as num?)?.toInt() ?? 0,
      expiresAt: expires is String ? DateTime.tryParse(expires) : null,
      qrisCode: data['qrisCode'] as String?,
      qrImageUrl: '$baseUrl$path',
    );
  }

  Future<DevDonationStatus> status(String trxId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/status/${Uri.encodeComponent(trxId)}',
      );
      final data = response.data ?? const <String, dynamic>{};
      final now = data['now'];
      return DevDonationStatus(
        switch (data['status']) {
          'paid' => DevDonationState.paid,
          'expired' => DevDonationState.expired,
          'pending' => DevDonationState.pending,
          _ => DevDonationState.unknown,
        },
        serverNow: now is num
            ? DateTime.fromMillisecondsSinceEpoch(now.toInt())
            : null,
      );
    } on DioException {
      return const DevDonationStatus(DevDonationState.unknown);
    }
  }
}

final devDonationApiProvider = Provider<DevDonationApi>(
  (ref) => DevDonationApi(),
);
