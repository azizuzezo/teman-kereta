import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Flat surface with a hairline border. Hierarchy comes from [tone], not from
/// shadows. Set [onTap] to make the whole card a 48dp+ touch target.
class TkCard extends StatelessWidget {
  const TkCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.tone = TkCardTone.surface,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final TkCardTone tone;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final (fill, line) = switch (tone) {
      TkCardTone.surface => (tk.surface, tk.border),
      TkCardTone.soft => (tk.primarySoft, Colors.transparent),
      TkCardTone.alt => (tk.surfaceAlt, Colors.transparent),
      TkCardTone.accent => (tk.accentSoft, Colors.transparent),
      TkCardTone.warning => (tk.warningSoft, Colors.transparent),
      TkCardTone.success => (tk.successSoft, Colors.transparent),
    };
    final radius = BorderRadius.circular(TkRadius.card);
    final content = Padding(padding: padding, child: child);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: line),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: content,
                ),
              ),
      ),
    );
  }
}

enum TkCardTone { surface, soft, alt, accent, warning, success }

/// Status pill. Pills are reserved for status so shape signals function.
class TkPill extends StatelessWidget {
  const TkPill({
    required this.label,
    super.key,
    this.icon,
    this.tone = TkPillTone.neutral,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final TkPillTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final (bg, fg) = switch (tone) {
      TkPillTone.neutral => (tk.surfaceAlt, tk.text),
      TkPillTone.primary => (tk.primarySoft, tk.primary),
      TkPillTone.accent => (tk.accentSoft, tk.accent),
      TkPillTone.success => (tk.successSoft, tk.success),
      TkPillTone.warning => (tk.warningSoft, tk.warning),
      TkPillTone.danger => (tk.dangerSoft, tk.danger),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontSize: dense ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum TkPillTone { neutral, primary, accent, success, warning, danger }

/// Small section label above a group of rows or cards.
class TkSectionLabel extends StatelessWidget {
  const TkSectionLabel(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: trailing == null
          ? _labelText(context)
          // Label left, trailing widget right. When both do not fit (large
          // text), the trailing widget drops to its own line instead of
          // overflowing or being squeezed.
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: <Widget>[_labelText(context), trailing!],
            ),
    );
  }
}

extension on TkSectionLabel {
  Text _labelText(BuildContext context) => Text(
    label,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(color: context.tk.textMuted),
  );
}

/// A row inside a grouped settings card: leading icon tile, title, optional
/// subtitle and trailing widget. 56dp minimum height.
class TkRow extends StatelessWidget {
  const TkRow({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final fg = destructive ? tk.danger : tk.text;
    final tile = destructive ? tk.dangerSoft : tk.primarySoft;
    final tileFg = destructive ? tk.danger : tk.primary;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tile,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: tileFg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(color: fg),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: textTheme.bodySmall),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: tk.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Groups [TkRow]s in one bordered card with hairline dividers between them.
class TkRowGroup extends StatelessWidget {
  const TkRowGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Material(
      color: tk.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TkRadius.card),
        side: BorderSide(color: tk.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, indent: 66, color: tk.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Circular avatar showing a network image or the initial of [name].
class TkAvatar extends StatelessWidget {
  const TkAvatar({
    required this.name,
    super.key,
    this.imageUrl,
    this.size = 44,
  });

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tk.primarySoft, shape: BoxShape.circle),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tk.primary,
          fontSize: size * 0.4,
        ),
      ),
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return Semantics(label: 'Avatar $name', image: true, child: fallback);
    }
    return Semantics(
      label: 'Foto $name',
      image: true,
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * 3).round(),
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
        ),
      ),
    );
  }
}

/// Loading placeholder. Pulses gently; static when animations are disabled.
class TkSkeleton extends StatefulWidget {
  const TkSkeleton({super.key, this.height = 16, this.width, this.radius = 8});

  final double height;
  final double? width;
  final double radius;

  @override
  State<TkSkeleton> createState() => _TkSkeletonState();
}

class _TkSkeletonState extends State<TkSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Color.lerp(
              tk.surfaceAlt,
              tk.border,
              _controller.value * 0.7,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for a card-shaped list item while data loads.
class TkListSkeleton extends StatelessWidget {
  const TkListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Memuat data',
      child: Column(
        children: <Widget>[
          for (var i = 0; i < count; i++) ...<Widget>[
            const TkCard(
              child: Row(
                children: <Widget>[
                  TkSkeleton(height: 44, width: 44, radius: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TkSkeleton(height: 14, width: 160),
                        SizedBox(height: 8),
                        TkSkeleton(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i < count - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Error state with a retry action.
class TkErrorState extends StatelessWidget {
  const TkErrorState({
    required this.message,
    super.key,
    this.onRetry,
    this.title = 'Gagal memuat',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tk.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, color: tk.danger, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tk.textMuted,
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The identity motif: station dots joined by a vertical route line, as on
/// the logo's track and every trip timeline. [filled] marks passed stops.
class TkRouteDots extends StatelessWidget {
  const TkRouteDots({
    required this.count,
    super.key,
    this.filled = 0,
    this.height = 56,
  });

  final int count;
  final int filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return ExcludeSemantics(
      child: SizedBox(
        width: 14,
        height: height,
        child: CustomPaint(
          painter: _RouteDotsPainter(
            count: count,
            filled: filled,
            on: tk.accent,
            off: tk.border,
            fillColor: tk.surface,
          ),
        ),
      ),
    );
  }
}

class _RouteDotsPainter extends CustomPainter {
  _RouteDotsPainter({
    required this.count,
    required this.filled,
    required this.on,
    required this.off,
    required this.fillColor,
  });

  final int count;
  final int filled;
  final Color on;
  final Color off;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (count < 2) {
      return;
    }
    final x = size.width / 2;
    final step = (size.height - 10) / (count - 1);
    final line = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count - 1; i++) {
      line.color = i < filled - 1 ? on : off;
      canvas.drawLine(
        Offset(x, 5 + step * i),
        Offset(x, 5 + step * (i + 1)),
        line,
      );
    }
    for (var i = 0; i < count; i++) {
      final center = Offset(x, 5 + step * i);
      final reached = i < filled;
      canvas.drawCircle(center, 5, Paint()..color = reached ? on : off);
      if (!reached) {
        canvas.drawCircle(center, 2.5, Paint()..color = fillColor);
      }
    }
  }

  @override
  bool shouldRepaint(_RouteDotsPainter old) =>
      old.count != count ||
      old.filled != filled ||
      old.on != on ||
      old.off != off;
}
