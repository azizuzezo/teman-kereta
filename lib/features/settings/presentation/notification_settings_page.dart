import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/tk_components.dart';
import 'settings_controller.dart';
import 'widgets/settings_rows.dart';

/// How many stations before the destination the countdown alerts begin.
const kStopAlertThresholds = <int>[5, 3, 2, 1];

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan notifikasi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            const TkSectionLabel('Bentuk peringatan'),
            TkRowGroup(
              children: <Widget>[
                SettingsSwitchRow(
                  icon: Icons.vibration_rounded,
                  title: 'Getaran',
                  value: settings.vibrationEnabled,
                  onChanged: controller.setVibrationEnabled,
                ),
                SettingsSwitchRow(
                  icon: Icons.volume_up_outlined,
                  title: 'Suara',
                  value: settings.soundEnabled,
                  onChanged: controller.setSoundEnabled,
                ),
                TkRow(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Tes suara peringatan',
                  subtitle: 'Dengarkan nada tiap peringatan sebelum jalan.',
                  onTap: () => context.push('/settings/sound-test'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const TkSectionLabel('Mulai peringatan dari'),
            const SettingsIntro(
              'Notifikasi dikirim berturut-turut mulai dari jumlah stasiun '
              'yang kamu pilih sampai tiba di tujuan.',
            ),
            TkRowGroup(
              children: <Widget>[
                for (final threshold in kStopAlertThresholds)
                  SettingsChoiceRow(
                    icon: Icons.notifications_active_outlined,
                    title: '$threshold stasiun sebelum tujuan',
                    selected: settings.stopAlertThreshold == threshold,
                    onTap: () => controller.setStopAlertThreshold(threshold),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
