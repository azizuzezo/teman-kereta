import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/updates/update_checker.dart';
import '../../../core/widgets/tk_logo.dart';

class AppUpdatePage extends ConsumerWidget {
  const AppUpdatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(packageInfoProvider);
    final pendingUpdate = ref.watch(updateCheckerControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tentang & pembaruan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: <Widget>[
            const Center(child: TkLogo(size: 64, showLabel: false)),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Teman Kereta',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                packageInfo.when(
                  data: (info) => 'Versi ${info.version} (${info.buildNumber})',
                  loading: () => 'Memuat versi…',
                  error: (_, _) => 'Versi tidak diketahui',
                ),
              ),
            ),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      pendingUpdate != null
                          ? Icons.system_update_outlined
                          : Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            pendingUpdate != null
                                ? 'Pembaruan tersedia: versi ${pendingUpdate.versionName}'
                                : 'Kamu menggunakan versi terbaru',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            pendingUpdate != null
                                ? ((pendingUpdate.changelog?.isNotEmpty ?? false)
                                    ? pendingUpdate.changelog!
                                    : 'Ketuk tombol di bawah untuk memasang versi terbaru.')
                                : 'Aplikasi ini dipasang langsung (bukan lewat Play Store) — '
                                      'pembaruan diperiksa otomatis setiap kali dibuka.',
                          ),
                          const SizedBox(height: 12),
                          if (pendingUpdate != null)
                            FilledButton(
                              onPressed: () => unawaited(
                                showUpdateAvailableDialog(context, pendingUpdate),
                              ),
                              child: const Text('Update sekarang'),
                            )
                          else
                            OutlinedButton(
                              onPressed: () =>
                                  ref.invalidate(updateCheckerControllerProvider),
                              child: const Text('Cek pembaruan'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privasi lokal'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/privacy'),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: const Text('Bantuan'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/help'),
            ),
          ],
        ),
      ),
    );
  }
}
