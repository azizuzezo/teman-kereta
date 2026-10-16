import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';
import 'package:teman_kereta/core/updates/update_checker.dart';
import 'package:teman_kereta/core/widgets/tk_components.dart';
import 'package:teman_kereta/features/account/presentation/account_controller.dart';
import 'package:teman_kereta/features/settings/presentation/permission_status.dart';
import 'package:teman_kereta/features/settings/presentation/profile_page.dart';

class _FakeAccount extends AccountController {
  _FakeAccount(this.user);

  final User? user;
  int signOutCalls = 0;

  @override
  AsyncValue<User?> build() => AsyncValue.data(user);

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}

User _user() => const User(
  id: 'user-1',
  appMetadata: <String, dynamic>{},
  userMetadata: <String, dynamic>{},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
  email: 'budi@example.com',
);

Future<void> _pump(
  WidgetTester tester, {
  required _FakeAccount account,
  Future<String?> Function(Ref ref)? name,
  Future<String?> Function(Ref ref)? username,
  Map<String, Object?> permissions = const <String, Object?>{
    'foregroundLocation': true,
    'backgroundLocation': false,
    'notifications': false,
  },
  double textScale = 1.0,
  Size size = const Size(390, 5000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesStoreProvider.overrideWithValue(MemoryPreferencesStore()),
        accountControllerProvider.overrideWith(() => account),
        userDisplayNameProvider.overrideWith(
          name ?? (ref) async => 'Budi Santoso',
        ),
        userUsernameProvider.overrideWith(username ?? (ref) async => 'budi'),
        userAvatarUrlProvider.overrideWith((ref) async => null),
        userFollowCountsProvider.overrideWith(
          (ref) async => (followers: 12, following: 7),
        ),
        devicePermissionStatusProvider.overrideWith((ref) async => permissions),
        packageInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'Teman Kereta',
            packageName: 'id.temankereta.teman_kereta',
            version: '1.0.15',
            buildNumber: '16',
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ProfilePage(),
      ),
    ),
  );
}

double _top(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder.first).dy;

void main() {
  testWidgets('signed in: profile card first, account actions last', (
    tester,
  ) async {
    await _pump(tester, account: _FakeAccount(_user()));
    await tester.pumpAndSettle();

    final order = <String, double>{
      'card': _top(tester, find.text('Budi Santoso')),
      'Sosial': _top(tester, find.text('Sosial')),
      'Pengaturan': _top(tester, find.text('Pengaturan')),
      'Tampilan': _top(tester, find.text('Tampilan')),
      'Perjalanan': _top(tester, find.text('Perjalanan')),
      'Bantuan': _top(tester, find.text('Bantuan')),
      'Akun': _top(tester, find.text('Akun')),
      'Keluar': _top(tester, find.text('Keluar')),
      'Hapus akun': _top(tester, find.text('Hapus akun')),
    };
    final tops = order.values.toList();
    for (var i = 1; i < tops.length; i++) {
      expect(
        tops[i],
        greaterThan(tops[i - 1]),
        reason:
            '${order.keys.elementAt(i)} must sit below '
            '${order.keys.elementAt(i - 1)}',
      );
    }
    // The destructive actions are the last two rows of the whole page.
    final lastBantuanRow = _top(tester, find.text('Ulangi pengenalan'));
    expect(order['Keluar']!, greaterThan(lastBantuanRow));
  });

  testWidgets('profile card shows only photo, name, username and counts', (
    tester,
  ) async {
    await _pump(tester, account: _FakeAccount(_user()));
    await tester.pumpAndSettle();

    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('@budi'), findsOneWidget);
    expect(find.text('12'), findsWidgets);
    expect(find.text('7'), findsWidgets);
    // No email, no station block, no widget entry, no GTFS import row.
    expect(find.text('budi@example.com'), findsNothing);
    expect(find.textContaining('Stasiun komuter'), findsNothing);
    expect(find.textContaining('Stasiun rumah'), findsNothing);
    expect(find.textContaining('Widget'), findsNothing);
    expect(find.textContaining('GTFS'), findsNothing);

    // Sign-out / delete are outside the card.
    final card = find.ancestor(
      of: find.text('@budi'),
      matching: find.byType(TkCard),
    );
    expect(
      find.descendant(of: card, matching: find.text('Keluar')),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.text('Hapus akun')),
      findsNothing,
    );
  });

  testWidgets('sections contain exactly the requested rows', (tester) async {
    await _pump(tester, account: _FakeAccount(_user()));
    await tester.pumpAndSettle();

    for (final label in <String>[
      'Cari pengguna',
      'Pengguna diblokir',
      'Lokasi',
      'Aktifkan notifikasi',
      'Pengaturan notifikasi',
      'Aksesibilitas',
      'Tes suara',
      'Riwayat perjalanan',
      'Rekap perjalanan',
      'Pusat bantuan',
      'Laporkan masalah',
      'Kebijakan privasi',
      'Tentang & pembaruan',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Versi 1.0.15'), findsOneWidget);
    // Follower / following rows exist in Sosial and as stats in the card.
    expect(find.text('Pengikut'), findsNWidgets(2));
    expect(find.text('Mengikuti'), findsNWidgets(2));
    // Theme switcher lives in Tampilan.
    expect(find.text('Mode tampilan'), findsOneWidget);
    expect(find.text('Navy KRL'), findsOneWidget);
  });

  testWidgets('permission rows show live status subtitles', (tester) async {
    await _pump(tester, account: _FakeAccount(_user()));
    await tester.pumpAndSettle();

    expect(find.text('Diizinkan saat aplikasi dibuka'), findsOneWidget);
    expect(
      find.text('Belum diizinkan, ketuk untuk mengizinkan'),
      findsOneWidget,
    );
  });

  testWidgets('guest sees a sign-in button and no account actions', (
    tester,
  ) async {
    await _pump(tester, account: _FakeAccount(null));
    await tester.pumpAndSettle();

    expect(find.text('Masuk atau buat akun'), findsOneWidget);
    expect(find.text('Keluar'), findsNothing);
    expect(find.text('Hapus akun'), findsNothing);
    expect(find.text('Sosial'), findsNothing);
    // Settings stay available without an account.
    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Riwayat perjalanan'), findsOneWidget);
  });

  testWidgets('shows a skeleton while the profile loads', (tester) async {
    final never = Completer<String?>();
    await _pump(
      tester,
      account: _FakeAccount(_user()),
      name: (ref) => never.future,
    );
    await tester.pump();

    expect(find.byType(TkSkeleton), findsWidgets);
    expect(find.text('Budi Santoso'), findsNothing);
    // The rest of the page is already usable.
    expect(find.text('Pengaturan'), findsOneWidget);
  });

  testWidgets('shows an error state with retry when the fetch fails', (
    tester,
  ) async {
    await _pump(
      tester,
      account: _FakeAccount(_user()),
      username: (ref) async => throw StateError('offline'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil belum bisa dimuat'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('sign out asks for confirmation first', (tester) async {
    final account = _FakeAccount(_user());
    await _pump(tester, account: account);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari akun?'), findsOneWidget);
    expect(account.signOutCalls, 0);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(account.signOutCalls, 0);

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Keluar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(account.signOutCalls, 1);
  });

  testWidgets('survives 1.3x text scale on a 360dp screen', (tester) async {
    await _pump(
      tester,
      account: _FakeAccount(_user()),
      textScale: 1.3,
      size: const Size(360, 6000),
      name: (ref) async => 'Nama Panjang Sekali Untuk Menguji Lipatan',
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('permission summaries', () {
    test('location', () {
      expect(
        locationPermissionSummary(const <String, Object?>{}),
        'Atur izin dan deteksi naik KRL',
      );
      expect(
        locationPermissionSummary(const <String, Object?>{
          'foregroundLocation': false,
        }),
        'Izin belum diberikan',
      );
      expect(
        locationPermissionSummary(const <String, Object?>{
          'foregroundLocation': true,
          'backgroundLocation': true,
        }),
        'Diizinkan, termasuk di latar belakang',
      );
    });

    test('notifications', () {
      expect(
        notificationPermissionSummary(const <String, Object?>{}),
        'Ketuk untuk meminta izin',
      );
      expect(
        notificationPermissionSummary(const <String, Object?>{
          'notifications': true,
        }),
        'Diizinkan',
      );
    });
  });
}
