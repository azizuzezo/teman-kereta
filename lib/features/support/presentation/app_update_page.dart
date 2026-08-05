import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/tk_logo.dart';

class AppUpdatePage extends StatelessWidget {
  const AppUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
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
            const Center(child: Text('Versi 0.1.0')),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.system_update_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Pengecekan pembaruan belum tersedia',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Build lokal ini belum terhubung ke Play Store atau server '
                            'pembaruan mana pun. Pasang versi terbaru secara manual saat tersedia.',
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
