import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_controller.dart';

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
            Text(
              'Bentuk peringatan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    value: settings.vibrationEnabled,
                    onChanged: controller.setVibrationEnabled,
                    secondary: const Icon(Icons.vibration_rounded),
                    title: const Text('Getaran'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: settings.soundEnabled,
                    onChanged: controller.setSoundEnabled,
                    secondary: const Icon(Icons.volume_up_outlined),
                    title: const Text('Suara'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Waktu peringatan sebelum tujuan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Notifikasi akan dikirim berturut-turut mulai dari jumlah stasiun ini.',
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: <int>[5, 3, 2, 1].map((threshold) {
                  return RadioListTile<int>(
                    value: threshold,
                    groupValue: settings.stopAlertThreshold,
                    onChanged: (value) {
                      if (value != null) {
                        controller.setStopAlertThreshold(value);
                      }
                    },
                    title: Text('$threshold stasiun sebelum tujuan'),
                  );
                }).toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
