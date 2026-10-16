import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/updates/update_checker.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../core/widgets/tk_logo.dart';
import '../support_links.dart';
import 'support_widgets.dart';

/// Tentang & pembaruan (`/about`).
class AppUpdatePage extends ConsumerWidget {
  const AppUpdatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final packageInfo = ref.watch(packageInfoProvider);
    final versionLabel = packageInfo.when(
      data: (info) => 'Versi ${info.version} (${info.buildNumber})',
      loading: () => 'Memuat versi',
      error: (_, _) => 'Versi tidak diketahui',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Tentang & pembaruan')),
      body: SupportPageBody(
        children: <Widget>[
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: <Widget>[
                const TkLogo(size: 72, showLabel: false),
                const SizedBox(height: 14),
                Text('Teman Kereta', style: textTheme.headlineSmall),
                const SizedBox(height: 6),
                TkPill(label: versionLabel, tone: TkPillTone.primary),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SupportParagraph(
            'Teman Kereta menemani perjalanan KRL Jabodetabek: jadwal keberangkatan, '
            'peringatan saat hampir tiba di stasiun tujuan, peta jalur, dan forum untuk bertanya ke sesama pengguna. '
            'Aplikasi ini independen dan bukan aplikasi resmi PT Kereta Commuter Indonesia (KAI Commuter).',
          ),
          const SupportSectionLabel('Pembaruan'),
          const _UpdateCard(),
          const SupportSectionLabel('Sumber data'),
          TkCard(
            tone: TkCardTone.alt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SourceLine(
                  title: 'Jadwal dan stasiun',
                  body:
                      'Data jadwal KRL Jabodetabek berformat GTFS yang disimpan di server Teman Kereta. '
                      'Bisa berbeda dengan kondisi di lapangan.',
                  textTheme: textTheme,
                  muted: tk.textMuted,
                ),
                const SizedBox(height: 12),
                _SourceLine(
                  title: 'Posisi kereta di peta',
                  body:
                      'Perkiraan dari jadwal dan posisi penumpang yang mengaktifkan Deteksi otomatis naik KRL.',
                  textTheme: textTheme,
                  muted: tk.textMuted,
                ),
                const SizedBox(height: 12),
                _SourceLine(
                  title: 'Peta dasar',
                  body: '© kontributor OpenStreetMap.',
                  textTheme: textTheme,
                  muted: tk.textMuted,
                ),
              ],
            ),
          ),
          const SupportSectionLabel('Tautan'),
          TkRowGroup(
            children: <Widget>[
              TkRow(
                icon: Icons.language_rounded,
                title: 'Situs web',
                subtitle: 'temankereta.web.id',
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () =>
                    openExternal(context, Uri.parse(SupportLinks.website)),
              ),
              TkRow(
                icon: Icons.mail_outline_rounded,
                title: 'Email dukungan',
                subtitle: SupportLinks.supportEmail,
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => openExternal(
                  context,
                  SupportLinks.mailto,
                  fallbackLabel: SupportLinks.supportEmail,
                ),
              ),
              TkRow(
                icon: Icons.help_outline_rounded,
                title: 'Bantuan',
                onTap: () => context.push('/help'),
              ),
              TkRow(
                icon: Icons.flag_outlined,
                title: 'Laporkan masalah',
                onTap: () => context.push('/report'),
              ),
              TkRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Privasi',
                onTap: () => context.push('/privacy'),
              ),
              TkRow(
                icon: Icons.delete_outline_rounded,
                title: 'Hapus akun',
                subtitle: 'Halaman permintaan penghapusan di situs web',
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => openExternal(
                  context,
                  Uri.parse(SupportLinks.deleteAccount),
                ),
              ),
              TkRow(
                icon: Icons.article_outlined,
                title: 'Lisensi pustaka',
                subtitle: 'Perangkat lunak pihak ketiga yang dipakai aplikasi',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Teman Kereta',
                  applicationVersion: packageInfo.value?.version,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '© 2026 Teman Kereta by duacincin.id',
              style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({
    required this.title,
    required this.body,
    required this.textTheme,
    required this.muted,
  });

  final String title;
  final String body;
  final TextTheme textTheme;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          body,
          style: textTheme.bodyMedium?.copyWith(color: muted, height: 1.4),
        ),
      ],
    );
  }
}

/// What the update card shows, derived from the manual check and the
/// automatic startup check. Pure, so it is unit-tested.
@visibleForTesting
UpdateCheckState effectiveUpdateState(
  UpdateCheckState manual,
  PendingAppUpdate? startup,
) {
  if (manual.phase != UpdateCheckPhase.idle || startup == null) {
    return manual;
  }
  return UpdateCheckState(phase: UpdateCheckPhase.available, update: startup);
}

class _UpdateCard extends ConsumerWidget {
  const _UpdateCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final info = ref.watch(packageInfoProvider).value;
    final state = effectiveUpdateState(
      ref.watch(manualUpdateCheckProvider),
      ref.watch(updateCheckerControllerProvider),
    );
    final checking = state.phase == UpdateCheckPhase.checking;
    final update = state.update;

    final (
      IconData icon,
      Color iconColor,
      String title,
    ) = switch (state.phase) {
      UpdateCheckPhase.idle => (
        Icons.system_update_outlined,
        tk.primary,
        'Periksa versi terbaru',
      ),
      UpdateCheckPhase.checking => (
        Icons.sync_rounded,
        tk.primary,
        'Memeriksa pembaruan',
      ),
      UpdateCheckPhase.upToDate => (
        Icons.check_circle_outline_rounded,
        tk.success,
        'Kamu memakai versi terbaru',
      ),
      UpdateCheckPhase.available => (
        Icons.system_update_outlined,
        tk.accent,
        'Versi ${update?.versionName} tersedia',
      ),
      UpdateCheckPhase.error => (
        Icons.error_outline_rounded,
        tk.danger,
        'Pembaruan belum bisa diperiksa',
      ),
    };

    final String? detail = switch (state.phase) {
      UpdateCheckPhase.idle =>
        'Aplikasi memeriksa sendiri tiap kali dibuka. Kamu juga bisa memeriksanya sekarang.',
      UpdateCheckPhase.checking => null,
      UpdateCheckPhase.upToDate =>
        'Versi ${info?.version ?? ''} adalah yang terbaru'
            '${state.checkedAt == null ? '' : ', diperiksa pukul ${DateFormat('HH:mm').format(state.checkedAt!)}'}.',
      UpdateCheckPhase.available =>
        update?.forceUpdate ?? false
            ? 'Versi kamu sudah terlalu lama. Pasang versi baru untuk terus memakai Teman Kereta.'
            : null,
      UpdateCheckPhase.error => state.errorMessage,
    };

    final changelog = update?.changelog?.trim();

    return TkCard(
      tone: switch (state.phase) {
        UpdateCheckPhase.available => TkCardTone.accent,
        UpdateCheckPhase.error => TkCardTone.warning,
        _ => TkCardTone.surface,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              checking
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: textTheme.titleSmall),
                    if (detail != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: textTheme.bodyMedium?.copyWith(
                          color: tk.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (state.phase == UpdateCheckPhase.available &&
              changelog != null &&
              changelog.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text('Yang baru', style: textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(changelog, style: textTheme.bodyMedium?.copyWith(height: 1.4)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: state.phase == UpdateCheckPhase.available && update != null
                ? FilledButton.icon(
                    onPressed: () => openExternal(
                      context,
                      Uri.parse(update.apkUrl),
                      fallbackLabel: 'tautan unduhan',
                    ),
                    icon: const Icon(Icons.download_rounded),
                    label: Text('Unduh versi ${update.versionName}'),
                  )
                : OutlinedButton.icon(
                    onPressed: checking
                        ? null
                        : () => ref
                              .read(manualUpdateCheckProvider.notifier)
                              .check(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      state.phase == UpdateCheckPhase.error
                          ? 'Coba lagi'
                          : 'Cek pembaruan',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
