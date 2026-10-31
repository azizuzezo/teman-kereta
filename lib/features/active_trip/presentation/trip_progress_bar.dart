import 'package:flutter/material.dart';

/// The active-trip progress bar: the fill glides to each new position over
/// about one native sync interval, so with a fix every few seconds it reads
/// as one continuous movement to the right rather than a series of jumps. A
/// train rides the leading edge, and while the train is moving a soft
/// highlight sweeps along the filled part.
class TripProgressBar extends StatefulWidget {
  const TripProgressBar({
    required this.progress,
    required this.moving,
    required this.reduceMotion,
    required this.trackColor,
    required this.fillColor,
    required this.markerColor,
    required this.markerIconColor,
    super.key,
  });

  /// 0-1 across the whole trip.
  final double progress;

  /// In transit between stations: the highlight sweeps only then.
  final bool moving;

  /// Device reduce-motion or the trip's battery saver: jump straight to
  /// each position and skip the sweep.
  final bool reduceMotion;

  final Color trackColor;
  final Color fillColor;
  final Color markerColor;
  final Color markerIconColor;

  @override
  State<TripProgressBar> createState() => _TripProgressBarState();
}

class _TripProgressBarState extends State<TripProgressBar>
    with SingleTickerProviderStateMixin {
  static const _barHeight = 10.0;
  static const _markerSize = 28.0;

  /// Matches `ActiveTripController`'s native sync, so one glide ends about
  /// when the next position arrives.
  static const _glide = Duration(seconds: 4);

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _syncSweep();
  }

  @override
  void didUpdateWidget(TripProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSweep();
  }

  void _syncSweep() {
    final animate = widget.moving && !widget.reduceMotion;
    if (animate && !_sweep.isAnimating) {
      _sweep.repeat();
    } else if (!animate && _sweep.isAnimating) {
      _sweep
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.progress.clamp(0.0, 1.0);
    return SizedBox(
      height: _markerSize,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: target),
            duration: widget.reduceMotion ? Duration.zero : _glide,
            curve: Curves.linear,
            builder: (context, value, _) {
              final fillWidth = width * value;
              final markerLeft = (fillWidth - (_markerSize / 2)).clamp(
                0.0,
                width - _markerSize,
              );
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  Container(
                    height: _barHeight,
                    decoration: BoxDecoration(
                      color: widget.trackColor,
                      borderRadius: BorderRadius.circular(_barHeight / 2),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_barHeight / 2),
                    child: SizedBox(
                      width: fillWidth,
                      height: _barHeight,
                      child: AnimatedBuilder(
                        animation: _sweep,
                        builder: (context, _) => DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _sweep.isAnimating
                                ? _sweepGradient(_sweep.value)
                                : null,
                            color: _sweep.isAnimating ? null : widget.fillColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: markerLeft,
                    child: Container(
                      width: _markerSize,
                      height: _markerSize,
                      decoration: BoxDecoration(
                        color: widget.markerColor,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: widget.markerColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.train_rounded,
                        size: 18,
                        color: widget.markerIconColor,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// The fill colour with a lighter band at [t] (0-1) across it, moving
  /// left to right as [t] grows.
  LinearGradient _sweepGradient(double t) {
    final highlight = Color.lerp(widget.fillColor, Colors.white, 0.45)!;
    final center = -0.3 + (t * 1.6);
    return LinearGradient(
      colors: <Color>[
        widget.fillColor,
        highlight,
        widget.fillColor,
      ],
      stops: <double>[
        (center - 0.25).clamp(0.0, 1.0),
        center.clamp(0.0, 1.0),
        (center + 0.25).clamp(0.0, 1.0),
      ],
    );
  }
}
