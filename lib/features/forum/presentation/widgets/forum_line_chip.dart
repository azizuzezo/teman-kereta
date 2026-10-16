import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Rounded-rectangle tag naming a KRL line: a dot in the line's own brand
/// color plus its code. The label always uses theme text colors, so contrast
/// holds in every palette whatever color the line has.
///
/// Pass [onTap] for a selectable filter chip (hit area is 48dp tall even
/// though the chip draws 34dp); omit it for the static tag shown on a post.
class ForumLineChip extends StatelessWidget {
  const ForumLineChip({
    required this.label,
    super.key,
    this.color,
    this.selected = false,
    this.onTap,
    this.semanticLabel,
  });

  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final dot = color ?? tk.primary;
    final interactive = onTap != null;
    final chip = Container(
      height: interactive ? 34 : 26,
      padding: EdgeInsets.symmetric(horizontal: interactive ? 12 : 8),
      decoration: BoxDecoration(
        color: selected ? tk.primarySoft : tk.surfaceAlt,
        borderRadius: BorderRadius.circular(interactive ? 11 : 8),
        border: Border.all(
          color: selected ? tk.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? tk.primary : tk.text,
              ),
            ),
          ),
        ],
      ),
    );
    if (!interactive) {
      return Semantics(label: semanticLabel ?? 'Jalur $label', child: chip);
    }
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(widthFactor: 1, child: chip),
        ),
      ),
    );
  }
}
