import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/tk_components.dart';

/// One station in [TripRailTimeline], already resolved to a display name
/// and (when this station is a real transfer point) its instruction text,
/// so the widget itself stays free of station-lookup/domain-model concerns.
typedef RailStation = ({String name, String? transferInstruction});

/// The vertical rail line making up the "Urutan stasiun" list on the active
/// trip screen: past stops and the line already travelled in the primary
/// color, the hop currently underway filling in as [hopFraction] grows from
/// GPS, everything ahead left neutral, and the destination marked with the
/// accent. It visibly moves as the rider does.
///
/// Long routes collapse the middle of the already-passed stops behind a
/// single "N stasiun terlewat" row (tap to expand) and auto-scroll to the
/// current station on first build, so opening the screen mid-trip on a
/// 20-stop line doesn't dump the rider at the top of a long list.
class TripRailTimeline extends StatefulWidget {
  const TripRailTimeline({
    required this.stations,
    required this.currentIndex,
    required this.hopFraction,
    required this.reduceMotion,
    super.key,
  });

  final List<RailStation> stations;
  final int currentIndex;

  /// 0-1 progress from the current station toward the next one.
  final double hopFraction;

  /// True when the line-fill and pulse should render their end state
  /// immediately instead of animating: device reduce-motion, or the
  /// trip's own battery-saver mode.
  final bool reduceMotion;

  @override
  State<TripRailTimeline> createState() => _TripRailTimelineState();
}

class _TripRailTimelineState extends State<TripRailTimeline> {
  static const _collapseThreshold = 4;

  bool _showAllPast = false;
  final _currentRowKey = GlobalKey();
  bool _didScroll = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didScroll) {
      return;
    }
    _didScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _currentRowKey.currentContext;
      if (context == null) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        alignment: 0.3,
        duration: widget.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.stations.length;
    final hasCollapsible = widget.currentIndex > _collapseThreshold;
    const collapseStart = 1;
    final collapseEnd = widget.currentIndex - 2;

    final children = <Widget>[];
    var index = 0;
    while (index < total) {
      if (hasCollapsible &&
          !_showAllPast &&
          index >= collapseStart &&
          index <= collapseEnd) {
        children.add(
          _CollapsedPastDivider(
            count: collapseEnd - collapseStart + 1,
            onTap: () => setState(() => _showAllPast = true),
          ),
        );
        index = collapseEnd + 1;
        continue;
      }

      final isCurrent = index == widget.currentIndex;
      final isPast = index < widget.currentIndex;
      final isDestination = index == total - 1;
      final station = widget.stations[index];
      children.add(
        _RailRow(
          key: isCurrent ? _currentRowKey : null,
          name: station.name,
          isPast: isPast,
          isCurrent: isCurrent,
          isNext: index == widget.currentIndex + 1,
          isDestination: isDestination,
          isLast: index == total - 1,
          transferInstruction: station.transferInstruction,
          belowFraction: isCurrent ? widget.hopFraction : (isPast ? 1.0 : 0.0),
          reduceMotion: widget.reduceMotion,
        ),
      );
      index += 1;
    }
    return Column(children: children);
  }
}

class _CollapsedPastDivider extends StatelessWidget {
  const _CollapsedPastDivider({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      button: true,
      label: '$count stasiun terlewat, ketuk untuk menampilkan',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 28,
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: tk.textMuted,
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  '$count stasiun terlewat',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tk.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more_rounded, size: 18, color: tk.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailRow extends StatelessWidget {
  const _RailRow({
    required this.name,
    required this.isPast,
    required this.isCurrent,
    required this.isNext,
    required this.isDestination,
    required this.isLast,
    required this.belowFraction,
    required this.reduceMotion,
    this.transferInstruction,
    super.key,
  });

  final String name;
  final bool isPast;
  final bool isCurrent;
  final bool isNext;
  final bool isDestination;
  final bool isLast;
  // Non-null exactly when this row is a real transfer station: gives it a
  // distinct marker from an ordinary pass-through stop, per the platform
  // guidance already computed for this trip (see transfer_platform_guidance).
  final String? transferInstruction;

  /// How much of the line below this node is already-travelled:
  /// 1.0 for a past stop, 0.0 for one still ahead, and the live [hopFraction]
  /// for the one hop currently underway.
  final double belowFraction;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final isTransfer = transferInstruction != null;
    final (nodeColor, iconColor) = isDestination
        ? (tk.accent, tk.onAccent)
        : isCurrent
        ? (tk.primary, tk.onPrimary)
        : isPast
        ? (tk.primary, tk.onPrimary)
        : isTransfer
        ? (tk.warning, tk.surface)
        : (tk.surface, tk.textMuted);
    final icon = isDestination
        ? Icons.flag_rounded
        : isCurrent
        ? Icons.train_rounded
        : isTransfer
        ? Icons.compare_arrows_rounded
        : isPast
        ? Icons.check_rounded
        : Icons.circle_outlined;
    final label = isDestination
        ? '$name, tujuan'
        : isCurrent
        ? '$name, posisi saat ini'
        : isTransfer
        ? '$name, stasiun transit: $transferInstruction'
        : name;
    final emphasized = isCurrent || isDestination || isNext;

    return Semantics(
      label: label,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 28,
              child: Column(
                children: <Widget>[
                  _RailNode(
                    icon: icon,
                    color: nodeColor,
                    iconColor: iconColor,
                    ring:
                        !isPast && !isCurrent && !isDestination && !isTransfer,
                    pulse: isCurrent,
                    reduceMotion: reduceMotion,
                  ),
                  if (!isLast)
                    Expanded(
                      child: _RailConnector(
                        fraction: belowFraction,
                        reduceMotion: reduceMotion,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            name,
                            style:
                                (emphasized
                                        ? textTheme.titleMedium
                                        : textTheme.bodyLarge)
                                    ?.copyWith(
                                      fontWeight: emphasized
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: isPast ? tk.textMuted : tk.text,
                                    ),
                          ),
                        ),
                        if (isTransfer) ...<Widget>[
                          const SizedBox(width: 8),
                          const TkPill(
                            label: 'Transit',
                            tone: TkPillTone.warning,
                            dense: true,
                          ),
                        ] else if (isCurrent) ...<Widget>[
                          const SizedBox(width: 8),
                          const TkPill(
                            label: 'Sekarang',
                            tone: TkPillTone.primary,
                            dense: true,
                          ),
                        ] else if (isDestination) ...<Widget>[
                          const SizedBox(width: 8),
                          const TkPill(
                            label: 'Tujuan',
                            tone: TkPillTone.accent,
                            dense: true,
                          ),
                        ] else if (isNext) ...<Widget>[
                          const SizedBox(width: 8),
                          const TkPill(
                            label: 'Berikutnya',
                            tone: TkPillTone.neutral,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                    if (isTransfer)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          transferInstruction!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: tk.warning,
                            fontWeight: FontWeight.w600,
                          ),
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

class _RailConnector extends StatelessWidget {
  const _RailConnector({required this.fraction, required this.reduceMotion});

  final double fraction;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final clamped = fraction.clamp(0.0, 1.0);
    // A CustomPainter, not a Stack+FractionallySizedBox: this connector sits
    // inside an Expanded under IntrinsicHeight (to match the row's real
    // text height), and FractionallySizedBox has no sane answer when asked
    // for its *intrinsic* height: it crashed the layout pass here. A
    // childless CustomPaint reports 0 for that query (same as a plain
    // Container would), then paints the real fill against the concrete size
    // it gets during actual layout.
    return Center(
      child: SizedBox(
        width: 4,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: clamped),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          builder: (context, value, _) => CustomPaint(
            size: Size.infinite,
            painter: _RailConnectorPainter(
              fraction: value,
              backgroundColor: tk.border,
              filledColor: tk.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RailConnectorPainter extends CustomPainter {
  _RailConnectorPainter({
    required this.fraction,
    required this.backgroundColor,
    required this.filledColor,
  });

  final double fraction;
  final Color backgroundColor;
  final Color filledColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    if (fraction <= 0) {
      return;
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * fraction),
      Paint()..color = filledColor,
    );
  }

  @override
  bool shouldRepaint(covariant _RailConnectorPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.filledColor != filledColor;
}

class _RailNode extends StatefulWidget {
  const _RailNode({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.ring,
    required this.pulse,
    required this.reduceMotion,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;

  /// Draws a hairline ring (stops still ahead) so they read as open.
  final bool ring;
  final bool pulse;
  final bool reduceMotion;

  @override
  State<_RailNode> createState() => _RailNodeState();
}

class _RailNodeState extends State<_RailNode>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(_RailNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse ||
        oldWidget.reduceMotion != widget.reduceMotion) {
      _syncController();
    }
  }

  void _syncController() {
    if (widget.pulse && !widget.reduceMotion) {
      _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600),
      )..repeat(reverse: true);
    } else {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final dot = Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color,
        border: widget.ring ? Border.all(color: tk.border, width: 2) : null,
      ),
      child: ExcludeSemantics(
        child: Icon(widget.icon, size: 15, color: widget.iconColor),
      ),
    );
    if (!widget.pulse) {
      return SizedBox(width: 28, height: 28, child: Center(child: dot));
    }
    // A single breathing halo behind the "current" node only: one live
    // marker per screen, not a glow scattered across every element.
    final controller = _controller;
    Widget haloCircle(double opacity) => Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: opacity),
      ),
    );
    final halo = controller == null
        ? haloCircle(0.25)
        : AnimatedBuilder(
            animation: controller,
            builder: (context, _) => haloCircle(controller.value * 0.35),
          );
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(alignment: Alignment.center, children: <Widget>[halo, dot]),
    );
  }
}
