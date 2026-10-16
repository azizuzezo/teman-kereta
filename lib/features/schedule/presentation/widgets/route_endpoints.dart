import 'package:flutter/material.dart';

import '../../../../core/widgets/tk_components.dart';

/// Two stacked rows (origin on top, destination below) joined by the route
/// line motif. Row height follows the text scale so the dots stay centered
/// on their rows at any accessibility size.
class RouteEndpoints extends StatelessWidget {
  const RouteEndpoints({
    required this.top,
    required this.bottom,
    super.key,
    this.rowHeight = 30,
    this.highlighted = false,
  });

  final Widget top;
  final Widget bottom;
  final double rowHeight;

  /// Fills the dots with the accent color (one emphasized card per list).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final h = rowHeight * scale;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 14,
          height: h * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                top: h / 2 - 5,
                left: 0,
                child: TkRouteDots(
                  count: 2,
                  filled: highlighted ? 2 : 0,
                  height: h + 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: h,
                child: Align(alignment: Alignment.centerLeft, child: top),
              ),
              SizedBox(
                height: h,
                child: Align(alignment: Alignment.centerLeft, child: bottom),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
