import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/tk_components.dart';
import '../settings_controller.dart';

/// Appearance card: pick light/dark/system and one of the color palettes.
/// Each option renders a live miniature of the real palette, so the choice is
/// visual rather than a text label.
class ThemeSwitcherCard extends ConsumerWidget {
  const ThemeSwitcherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final tk = context.tk;
    final systemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    return TkCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Mode tampilan', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Terang untuk siang hari, gelap untuk kereta malam.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              for (final mode in ThemeMode.values) ...<Widget>[
                Expanded(
                  child: _ModeTile(
                    mode: mode,
                    selected: settings.themeMode == mode,
                    previewColors: switch (mode) {
                      ThemeMode.light => TkPalettes.byId(
                        settings.palette,
                      ).light,
                      ThemeMode.dark => TkPalettes.byId(settings.palette).dark,
                      ThemeMode.system =>
                        TkPalettes.byId(settings.palette).forBrightness(
                          systemDark ? Brightness.dark : Brightness.light,
                        ),
                    },
                    onTap: () => controller.setThemeMode(mode),
                  ),
                ),
                if (mode != ThemeMode.values.last) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Text('Warna aplikasi', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Berlaku di mode terang dan gelap.', style: textTheme.bodySmall),
          const SizedBox(height: 12),
          for (final palette in TkPalettes.all) ...<Widget>[
            _PaletteRow(
              palette: palette,
              selected: settings.palette == palette.id,
              onTap: () => controller.setPalette(palette.id),
            ),
            if (palette != TkPalettes.all.last)
              Divider(height: 1, color: tk.border),
          ],
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.previewColors,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final TkColors previewColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final label = switch (mode) {
      ThemeMode.system => 'Sistem',
      ThemeMode.light => 'Terang',
      ThemeMode.dark => 'Gelap',
    };
    return Semantics(
      button: true,
      selected: selected,
      label: 'Mode $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TkRadius.control),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TkRadius.control),
            border: Border.all(
              color: selected ? tk.primary : tk.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: <Widget>[
              ExcludeSemantics(
                child: Stack(
                  children: <Widget>[
                    Container(
                      height: 64,
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: previewColors.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: previewColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            height: 8,
                            width: 28,
                            decoration: BoxDecoration(
                              color: previewColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: previewColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: previewColors.border),
                              ),
                              alignment: Alignment.bottomLeft,
                              padding: const EdgeInsets.all(5),
                              child: Container(
                                height: 4,
                                width: 18,
                                decoration: BoxDecoration(
                                  color: previewColors.accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: previewColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? tk.primary : tk.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final TkPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final swatch = palette.forBrightness(tk.brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Warna ${palette.label}, ${palette.description}',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                ExcludeSemantics(
                  child: SizedBox(
                    width: 52,
                    height: 28,
                    child: Stack(
                      children: <Widget>[
                        Positioned(left: 0, child: _Dot(color: swatch.primary)),
                        Positioned(left: 18, child: _Dot(color: swatch.accent)),
                        Positioned(
                          left: 36,
                          child: _Dot(color: swatch.primarySoft),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(palette.label, style: textTheme.titleSmall),
                      Text(palette.description, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? tk.primary : tk.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: context.tk.surface, width: 2),
      ),
    );
  }
}
