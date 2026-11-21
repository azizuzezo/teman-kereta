import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/features/support/data/dev_donation_api.dart';
import 'package:teman_kereta/features/support/data/donor_contact.dart';
import 'package:teman_kereta/features/support/presentation/dev_donation_sheet.dart';

class _FakeContacts implements DonorContactStore {
  _FakeContacts({this.email, this.phone});

  @override
  String? email;
  @override
  String? phone;

  @override
  Future<void> savePhone(String value) async => phone = value;
}

const _gopay = DevDonationConfig(
  provider: 'gopay',
  requiresEmail: false,
  requiresPhone: false,
  minAmount: 10000,
);
const _mayar = DevDonationConfig(
  provider: 'mayar',
  requiresEmail: true,
  requiresPhone: true,
  minAmount: 10000,
);

class _FakeApi extends DevDonationApi {
  _FakeApi({
    this.state = DevDonationState.paid,
    this.failCreate = false,
    this.cfg = _gopay,
  });

  final DevDonationState state;
  final bool failCreate;
  DevDonationConfig cfg;
  bool offline = false;
  DevDonationException? createError;
  int? createdAmount;
  String? createdName;
  String? createdEmail;
  String? createdPhone;

  @override
  Future<DevDonationConfig> config({int? amount}) async {
    if (offline) {
      throw const DevDonationException('Server pembayaran tidak terjangkau.');
    }
    return cfg;
  }

  @override
  Future<DevDonationQris> create({
    required int amount,
    String? name,
    String? message,
    String? email,
    String? phone,
  }) async {
    final error = createError;
    if (error != null) throw error;
    if (failCreate) {
      throw const DevDonationException('QRIS belum bisa dibuat. Coba lagi sebentar.');
    }
    createdAmount = amount;
    createdName = name;
    createdEmail = email;
    createdPhone = phone;
    return DevDonationQris(
      trxId: 'trx-1',
      amount: amount + 57,
      baseAmount: amount,
      fee: 0,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      qrisCode: '00020101021226670016COM.NOBUBANK.WWW01189360050300000879140214',
      qrImageUrl: 'https://patungan.gifts/dev/qris/x',
    );
  }

  @override
  Future<DevDonationStatus> status(String trxId) async =>
      DevDonationStatus(state, serverNow: DateTime.now());
}

Widget _app(DevDonationApi api, {DonorContactStore? contacts}) => ProviderScope(
  overrides: [
    devDonationApiProvider.overrideWithValue(api),
    donorContactStoreProvider.overrideWithValue(
      contacts ?? _FakeContacts(email: 'aziz@skor.co'),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showDevDonationSheet(context),
            child: const Text('buka'),
          ),
        ),
      ),
    ),
  ),
);

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);

  final (int, Object) Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, body) = handler(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('layar dukungan', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('pilih nominal, QRIS tampil, lalu otomatis berterima kasih saat lunas', (
      tester,
    ) async {
      final api = _FakeApi();
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(api));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('Dukung Pengembang'), findsOneWidget);
      await tester.tap(find.text('3 kopi  Rp30.000'));
      await tester.pump();
      await tester.tap(find.text('Buat QRIS'));
      await tester.pump();
      await tester.pump();

      expect(api.createdAmount, 30000);
      expect(find.text('Rp30.057'), findsOneWidget);
      expect(find.textContaining('Menunggu pembayaran'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('Terima kasih!'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('QRIS kedaluwarsa menawarkan membuat yang baru', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(_FakeApi(state: DevDonationState.expired)));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat QRIS'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.text('QRIS sudah kedaluwarsa'), findsOneWidget);
      await tester.tap(find.text('Buat QRIS baru'));
      await tester.pump();
      expect(find.text('Buat QRIS'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('gagal membuat QRIS menampilkan pesan dan jalan lewat web', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(_FakeApi(failCreate: true)));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat QRIS'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('QRIS belum bisa dibuat'), findsOneWidget);
      expect(find.text('Bayar lewat halaman web'), findsOneWidget);
    });

    testWidgets('nominal lain wajib diisi', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(_FakeApi()));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nominal lain'));
      await tester.pump();
      await tester.tap(find.text('Buat QRIS'));
      await tester.pump();
      expect(find.text('Isi nominal dulu.'), findsOneWidget);
    });
  });

  group('QRIS Mayar dan status online', () {
    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('GoPay: tidak ada isian kontak', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(_app(_FakeApi()));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      expect(find.text('Nomor HP'), findsNothing);
      expect(find.text('Email'), findsNothing);
    });

    testWidgets('Mayar: hanya nomor HP diminta, email dari akun, lalu nomor tersimpan di akun', (
      tester,
    ) async {
      bigScreen(tester);
      final api = _FakeApi(cfg: _mayar);
      final contacts = _FakeContacts(email: 'aziz@skor.co');
      await tester.pumpWidget(_app(api, contacts: contacts));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('Nomor HP'), findsOneWidget);
      expect(find.text('Email'), findsNothing); // otomatis dari akun

      await tester.tap(find.text('Buat QRIS'));
      await tester.pump();
      expect(find.textContaining('nomor HP yang benar'), findsOneWidget);
      expect(api.createdAmount, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Nomor HP'), '081234567890');
      await tester.tap(find.text('Buat QRIS'));
      await tester.pump();
      await tester.pump();

      expect(api.createdEmail, 'aziz@skor.co');
      expect(api.createdPhone, '081234567890');
      expect(contacts.phone, '081234567890'); // tersimpan di akun
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('nomor yang sudah tersimpan tidak ditanyakan lagi', (tester) async {
      bigScreen(tester);
      final api = _FakeApi(cfg: _mayar);
      final contacts = _FakeContacts(email: 'aziz@skor.co', phone: '081200001111');
      await tester.pumpWidget(_app(api, contacts: contacts));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('Nomor HP'), findsNothing);
      expect(find.textContaining('nomor HP yang tersimpan'), findsOneWidget);
      await tester.tap(find.text('Buat QRIS'));
      await tester.pump();
      await tester.pump();
      expect(api.createdPhone, '081200001111');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tanpa akun, email ikut diminta', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        _app(_FakeApi(cfg: _mayar), contacts: _FakeContacts()),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Nomor HP'), findsOneWidget);
    });

    testWidgets('pemilik ganti QRIS di Patungan: form ikut berubah tanpa ditutup', (
      tester,
    ) async {
      bigScreen(tester);
      final api = _FakeApi();
      await tester.pumpWidget(_app(api));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      expect(find.text('Nomor HP'), findsNothing);

      api.cfg = _mayar; // pemilik memilih Mayar di Patungan
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(find.text('Nomor HP'), findsOneWidget);

      api.cfg = _gopay; // dan kembali ke GoPay
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(find.text('Nomor HP'), findsNothing);
    });

    testWidgets('server meminta kontak walau form belum menampilkannya', (tester) async {
      bigScreen(tester);
      final api = _FakeApi()
        ..createError = const DevDonationException(
          'Lengkapi data kontak dulu.',
          needsPhone: true,
        );
      await tester.pumpWidget(_app(api));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat QRIS'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Nomor HP'), findsOneWidget);
      expect(find.textContaining('Lengkapi data'), findsOneWidget);
    });

    testWidgets('offline: tombol mati, tersambung lagi otomatis menyala', (tester) async {
      bigScreen(tester);
      final api = _FakeApi()..offline = true;
      await tester.pumpWidget(_app(api));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tidak tersambung'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      api.offline = false;
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(find.textContaining('Tidak tersambung'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });
  });

  group('DevDonationApi', () {
    test('create membaca jawaban Patungan', () async {
      final dio = Dio()
        ..httpClientAdapter = _JsonAdapter((options) {
          expect(options.path, '/api/app/dev-donation');
          expect((options.data as Map)['amount'], 10000);
          return (
            200,
            <String, Object?>{
              'trxId': 'abc',
              'amount': 10057,
              'baseAmount': 10000,
              'fee': 0,
              'expiresAt': '2026-11-21T10:30:00.000Z',
              'qrisCode': '000201',
              'qrImagePath': '/dev/qris/q1',
            },
          );
        });
      final qris = await DevDonationApi(dio: dio).create(amount: 10000);
      expect(qris.trxId, 'abc');
      expect(qris.uniqueCode, 57);
      expect(qris.qrisCode, '000201');
      expect(qris.qrImageUrl, 'https://patungan.gifts/dev/qris/q1');
      expect(qris.expiresAt, DateTime.utc(2026, 11, 21, 10, 30));
    });

    test('nominal di bawah minimum membawa batasnya', () async {
      final dio = Dio()
        ..httpClientAdapter = _JsonAdapter(
          (_) => (400, <String, Object?>{'error': 'amount', 'min': 5000}),
        );
      await expectLater(
        DevDonationApi(dio: dio).create(amount: 100),
        throwsA(
          isA<DevDonationException>()
              .having((e) => e.minimum, 'minimum', 5000)
              .having((e) => e.retryable, 'retryable', false),
        ),
      );
    });

    test('status membaca lunas dan jam server', () async {
      final dio = Dio()
        ..httpClientAdapter = _JsonAdapter(
          (_) => (200, <String, Object?>{'status': 'paid', 'now': 1700000000000}),
        );
      final status = await DevDonationApi(dio: dio).status('abc');
      expect(status.state, DevDonationState.paid);
      expect(status.serverNow, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });

    test('server mati dianggap belum diketahui, bukan lunas', () async {
      final dio = Dio()
        ..httpClientAdapter = _JsonAdapter((_) => (500, <String, Object?>{}));
      final status = await DevDonationApi(dio: dio).status('abc');
      expect(status.state, DevDonationState.unknown);
    });
  });

  group('DevDonationApi: pengaturan dan kontak', () {
    test('config membaca pilihan QRIS yang aktif', () async {
      final dio = Dio()
        ..httpClientAdapter = _JsonAdapter((options) {
          expect(options.path, '/api/app/dev-donation/config');
          expect(options.queryParameters['amount'], 30000);
          return (
            200,
            <String, Object?>{
              'provider': 'mayar',
              'requiresEmail': true,
              'requiresPhone': true,
              'minAmount': 10000,
            },
          );
        });
      final config = await DevDonationApi(dio: dio).config(amount: 30000);
      expect(config, _mayar);
    });

    test('server tidak terjangkau melempar supaya aplikasi menandai offline', () async {
      final dio = Dio()
        ..httpClientAdapter = _ThrowingAdapter();
      await expectLater(
        DevDonationApi(dio: dio).config(),
        throwsA(isA<DevDonationException>()),
      );
    });

    test('422 contact_required membawa kontak yang kurang', () async {
      final dio = Dio()
        ..httpClientAdapter = _JsonAdapter(
          (_) => (
            422,
            <String, Object?>{
              'error': 'contact_required',
              'needs': <String, Object?>{'email': false, 'phone': true},
            },
          ),
        );
      await expectLater(
        DevDonationApi(dio: dio).create(amount: 10000),
        throwsA(
          isA<DevDonationException>()
              .having((e) => e.needsPhone, 'needsPhone', true)
              .having((e) => e.needsEmail, 'needsEmail', false),
        ),
      );
    });

    test('email dan nomor HP ikut terkirim bila ada', () async {
      final dio = Dio()
        ..httpClientAdapter = _JsonAdapter((options) {
          final data = options.data as Map;
          expect(data['email'], 'aziz@skor.co');
          expect(data['phone'], '081234567890');
          return (
            200,
            <String, Object?>{
              'trxId': 'abc',
              'amount': 10057,
              'baseAmount': 10000,
              'qrImagePath': '/dev/qris/q1',
            },
          );
        });
      await DevDonationApi(dio: dio).create(
        amount: 10000,
        email: 'aziz@skor.co',
        phone: '081234567890',
      );
    });
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );
  }

  @override
  void close({bool force = false}) {}
}
