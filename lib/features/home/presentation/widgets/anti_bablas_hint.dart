import 'package:flutter/material.dart';

import '../../../../core/widgets/tk_components.dart';

/// Small accent badge beside "Mulai perjalanan". It sits near the bottom of
/// Home, where riders may not realise that starting a trip is what turns on
/// the reminders, so it says so in their own words ("anti bablas").
class AntiBablasHint extends StatelessWidget {
  const AntiBablasHint({super.key});

  static const label = 'Diingatkan, anti bablas';
  static const explanation =
      'Kami ingatkan sebelum stasiun tujuanmu, supaya tidak kebablasan.';

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: explanation,
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: '$label. $explanation',
        excludeSemantics: true,
        child: const TkPill(
          label: label,
          icon: Icons.notifications_active_rounded,
          tone: TkPillTone.accent,
        ),
      ),
    );
  }
}
