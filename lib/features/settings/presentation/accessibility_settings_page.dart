import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_controller.dart';

class AccessibilitySettingsPage extends ConsumerWidget {
  const AccessibilitySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan aksesibilitas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Ukuran teks',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Berlaku di atas pengaturan ukuran teks perangkat, saat ini '
                      '${(settings.textScale * 100).round()}%.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: settings.textScale,
                      min: 0.85,
                      max: 1.6,
                      divisions: 15,
                      label: '${(settings.textScale * 100).round()}%',
                      onChanged: controller.setTextScale,
                    ),
                    Text(
                      'Contoh teks pada ukuran ini',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: SwitchListTile(
                value: settings.reduceMotion,
                onChanged: controller.setReduceMotion,
                secondary: const Icon(Icons.motion_photos_off_outlined),
                title: const Text('Kurangi animasi'),
                subtitle: const Text(
                  'Mengurangi transisi untuk kenyamanan dan aksesibilitas.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.record_voice_over_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'TK dirancang agar dapat digunakan dengan TalkBack: setiap ikon '
                        'penting memiliki label semantik dan status perjalanan tidak '
                        'hanya mengandalkan warna.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
