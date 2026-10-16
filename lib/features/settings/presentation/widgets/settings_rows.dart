import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/tk_components.dart';

/// A [TkRow] whose trailing control is a [Switch]. The whole row toggles, so
/// the touch target is the full 56dp row, and screen readers get one merged
/// "title, subtitle, switch" node.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final handler = onChanged;
    return MergeSemantics(
      child: TkRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: handler == null ? null : () => handler(!value),
        trailing: Switch(value: value, onChanged: handler),
      ),
    );
  }
}

/// A [TkRow] used as one option of a single-choice list (no Radio widget: the
/// check mark is the state, `selected` + `inMutuallyExclusiveGroup` is what a
/// screen reader announces).
class SettingsChoiceRow extends StatelessWidget {
  const SettingsChoiceRow({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    super.key,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: TkRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
        trailing: Icon(
          selected
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: selected ? tk.primary : tk.textMuted,
        ),
      ),
    );
  }
}

/// Status chip for a permission: success when granted, warning when not.
class PermissionPill extends StatelessWidget {
  const PermissionPill({required this.granted, super.key});

  final bool granted;

  @override
  Widget build(BuildContext context) {
    return TkPill(
      label: granted ? 'Diizinkan' : 'Belum',
      icon: granted ? Icons.check_rounded : Icons.close_rounded,
      tone: granted ? TkPillTone.success : TkPillTone.warning,
      dense: true,
    );
  }
}

/// Plain paragraph used for the short explanation at the top of a settings
/// page. Muted, so the controls below stay the focus.
class SettingsIntro extends StatelessWidget {
  const SettingsIntro(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.tk.textMuted),
      ),
    );
  }
}
