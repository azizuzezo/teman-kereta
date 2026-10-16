import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/tk_components.dart';
import 'settings_controller.dart';
import 'widgets/settings_rows.dart';

class AccessibilitySettingsPage extends ConsumerWidget {
  const AccessibilitySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final tk = context.tk;
    final percent = (settings.textScale * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan aksesibilitas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            const TkSectionLabel('Ukuran teks'),
            TkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Berlaku di atas ukuran teks perangkat.',
                          style: textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('$percent%', style: textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Slider(
                    value: settings.textScale,
                    min: 0.85,
                    max: 1.6,
                    divisions: 15,
                    label: '$percent%',
                    semanticFormatterCallback: (value) =>
                        'Ukuran teks ${(value * 100).round()} persen',
                    onChanged: controller.setTextScale,
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tk.surfaceAlt,
                      borderRadius: BorderRadius.circular(TkRadius.control),
                    ),
                    child: Text(
                      'Contoh teks pada ukuran ini',
                      style: textTheme.bodyLarge,
                    ),
                  ),
                  if ((settings.textScale - 1.0).abs() > 0.001)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => controller.setTextScale(1),
                        child: const Text('Kembalikan ke 100%'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const TkSectionLabel('Gerak'),
            TkRowGroup(
              children: <Widget>[
                SettingsSwitchRow(
                  icon: Icons.motion_photos_off_outlined,
                  title: 'Kurangi animasi',
                  subtitle:
                      'Mengurangi transisi untuk kenyamanan dan aksesibilitas.',
                  value: settings.reduceMotion,
                  onChanged: controller.setReduceMotion,
                ),
              ],
            ),
            const SizedBox(height: 20),
            TkCard(
              tone: TkCardTone.soft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.record_voice_over_outlined, color: tk.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'TK dirancang agar bisa dipakai dengan TalkBack: setiap '
                      'ikon penting punya label, dan status perjalanan tidak '
                      'hanya mengandalkan warna.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
