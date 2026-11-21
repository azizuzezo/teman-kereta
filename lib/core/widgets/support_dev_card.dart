import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../features/support/presentation/dev_donation_sheet.dart';
import 'tk_components.dart';

/// Membuka layar dukungan: pilih nominal, QRIS tampil di dalam aplikasi.
Future<void> openDeveloperSupportPage(BuildContext context) =>
    showDevDonationSheet(context);

/// Ajakan donasi yang tenang: satu kartu, satu tombol, tanpa menghalangi
/// apa pun. Tidak pernah muncul di tengah perjalanan.
class SupportDevCard extends StatelessWidget {
  const SupportDevCard({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    return TkCard(
      tone: TkCardTone.soft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.volunteer_activism_outlined, color: tk.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Teman Kereta gratis dan tanpa iklan',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Kalau aplikasi ini membantu, kamu bisa ikut patungan untuk '
                  'biaya server dan pengembangan. Bayar lewat QRIS, langsung '
                  'terkonfirmasi otomatis.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tk.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () =>
                      unawaited(openDeveloperSupportPage(context)),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                  label: const Text('Dukung Pengembang'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
