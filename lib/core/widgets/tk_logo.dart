import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// The TK badge on a rounded tile. The asset has an opaque white background,
/// so it always sits on this tile (with a hairline border) rather than
/// directly on the page, which keeps it clean on the dark theme as well.
class TkLogo extends StatelessWidget {
  const TkLogo({super.key, this.size = 44, this.showLabel = true});

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final radius = BorderRadius.circular(size * 0.24);
    return Semantics(
      label: 'Teman Kereta',
      image: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: tk.border),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Image.asset(
                  'assets/branding/tk_icon.png',
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            if (showLabel) ...<Widget>[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Teman Kereta',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
