import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/history_stats.dart';

/// Trips per weekday, Monday to Sunday, as one series of bars.
///
/// Meaning never rests on colour: every non-empty bar prints its count, every
/// bar has a day label, the busiest day is bold, and the whole chart has a
/// spoken summary. Colour only adds emphasis (busiest bar in the brand colour,
/// others in a tint that keeps 3:1 against the card).
class WeekdayHabitChart extends StatelessWidget {
  const WeekdayHabitChart({required this.counts, super.key, this.height = 140});

  final Map<int, int> counts;
  final double height;

  static const _shortNames = <int, String>{
    DateTime.monday: 'Sen',
    DateTime.tuesday: 'Sel',
    DateTime.wednesday: 'Rab',
    DateTime.thursday: 'Kam',
    DateTime.friday: 'Jum',
    DateTime.saturday: 'Sab',
    DateTime.sunday: 'Min',
  };

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    final busiest = busiestWeekday(counts);
    return Semantics(
      label: weekdayChartLabel(counts),
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _Bar(
                      count: counts[day] ?? 0,
                      maxCount: maxCount,
                      label: _shortNames[day]!,
                      isBusiest: day == busiest,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.count,
    required this.maxCount,
    required this.label,
    required this.isBusiest,
  });

  final int count;
  final int maxCount;
  final String label;
  final bool isBusiest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tk = context.tk;
    final fraction = maxCount == 0 ? 0.0 : count / maxCount;
    final barColor = isBusiest
        ? tk.primary
        : Color.lerp(tk.surface, tk.primary, 0.55)!;
    return Column(
      children: <Widget>[
        SizedBox(
          height: 18,
          child: count == 0
              ? null
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isBusiest ? tk.primary : tk.textMuted,
                      fontWeight: isBusiest ? FontWeight.w800 : FontWeight.w600,
                      fontFeatures: AppTheme.timeFeatures,
                    ),
                  ),
                ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: count == 0
                ? Container(height: 2, color: tk.border)
                : FractionallySizedBox(
                    heightFactor: fraction.clamp(0.04, 1.0),
                    widthFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isBusiest ? tk.text : tk.textMuted,
              fontWeight: isBusiest ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
