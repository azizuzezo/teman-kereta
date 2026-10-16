import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/geo.dart';
import '../../domain/history_stats.dart';
import 'share_data.dart';

/// Fixed brand colours for share cards. Cards are images that leave the app,
/// so they must look the same for every rider whatever theme is selected, and
/// stay legible in any chat app. These are deliberately not `context.tk`.
abstract final class ShareCardPalette {
  static const navy = Color(0xFF17376B);
  static const navyDeep = Color(0xFF0F2650);
  static const white = Color(0xFFFFFFFF);

  /// Secondary text on [navy], 6:1 contrast.
  static const soft = Color(0xFFB7C6E3);

  /// The one accent: KRL red from the logo, lifted slightly for the dark card.
  static const red = Color(0xFFE5333D);
  static const hairline = Color(0x33FFFFFF);
  static const barDim = Color(0x59FFFFFF);
}

const _fontFamily = 'PlusJakartaSans';
const _logoAsset = 'assets/branding/tk_icon.png';

TextStyle _style(
  double size, {
  FontWeight weight = FontWeight.w600,
  Color color = ShareCardPalette.white,
  double? letterSpacing,
  double height = 1.2,
  bool tabular = false,
}) {
  return TextStyle(
    fontFamily: _fontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    decoration: TextDecoration.none,
    fontFeatures: tabular
        ? const <FontFeature>[FontFeature.tabularFigures()]
        : null,
  );
}

/// What the preview sheet needs to know about a shareable thing: its title,
/// the caption sent with the image, and how to build the card for an aspect.
abstract class ShareCardSpec {
  const ShareCardSpec();

  String get sheetTitle;
  String get caption;

  /// File name stem, without extension.
  String get fileStem;

  Widget buildCard(ShareAspect aspect);
}

class TripShareSpec extends ShareCardSpec {
  const TripShareSpec(this.data);

  final TripShareData data;

  @override
  String get sheetTitle => 'Bagikan perjalanan';

  @override
  String get caption => data.caption;

  @override
  String get fileStem => 'perjalanan-selesai';

  @override
  Widget buildCard(ShareAspect aspect) =>
      TripShareCard(data: data, aspect: aspect);
}

class RecapShareSpec extends ShareCardSpec {
  const RecapShareSpec(this.data);

  final RecapShareData data;

  @override
  String get sheetTitle => 'Bagikan rekap';

  @override
  String get caption => data.caption;

  @override
  String get fileStem => 'rekap-perjalanan';

  @override
  Widget buildCard(ShareAspect aspect) =>
      RecapShareCard(data: data, aspect: aspect);
}

/// Shared frame: fixed size, brand navy, text scale pinned to 1 so the export
/// does not depend on the rider's accessibility settings.
class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.aspect,
    required this.semanticsLabel,
    required this.child,
  });

  final ShareAspect aspect;
  final String semanticsLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final story = aspect.isStory;
    return MediaQuery(
      data:
          MediaQuery.maybeOf(
            context,
          )?.copyWith(textScaler: TextScaler.noScaling, boldText: false) ??
          const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: _style(14),
          child: Semantics(
            container: true,
            label: semanticsLabel,
            child: ExcludeSemantics(
              child: SizedBox(
                width: aspect.size.width,
                height: aspect.size.height,
                child: ColoredBox(
                  color: ShareCardPalette.navy,
                  child: Padding(
                    // Story apps cover the top and bottom edges with their own
                    // chrome, so the content sits inside a safer band.
                    padding: EdgeInsets.fromLTRB(
                      28,
                      story ? 80 : 28,
                      28,
                      story ? 96 : 28,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: ShareCardPalette.white,
            borderRadius: BorderRadius.circular(11),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(_logoAsset, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Teman Kereta',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(15, weight: FontWeight.w800, letterSpacing: -0.2),
          ),
        ),
        Text(
          tag,
          maxLines: 1,
          style: _style(
            10.5,
            weight: FontWeight.w800,
            color: ShareCardPalette.soft,
            letterSpacing: 1.3,
          ),
        ),
      ],
    );
  }
}

/// "Perjalanan selesai": origin and destination on the route motif, the
/// duration as the focal number, then whichever real facts exist.
class TripShareCard extends StatelessWidget {
  const TripShareCard({required this.data, required this.aspect, super.key});

  final TripShareData data;
  final ShareAspect aspect;

  @override
  Widget build(BuildContext context) {
    final story = aspect.isStory;
    final duration = data.duration;
    final stations = data.visibleStationCount;
    final line = data.lineName;
    final facts = <(String, String)>[
      ('Tanggal', formatShortDate(data.date)),
      if (stations != null) ('Stasiun', '$stations'),
      if (line != null && line.trim().isNotEmpty) ('Jalur', line.trim()),
    ];

    return _CardShell(
      aspect: aspect,
      semanticsLabel: data.caption,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Header(tag: 'PERJALANAN SELESAI'),
          const Spacer(),
          _RouteNode(
            label: 'Dari',
            name: data.originName,
            isFirst: true,
            fontSize: story ? 28 : 24,
          ),
          _RouteConnector(
            height: story ? 52 : 36,
            midDots: stations == null ? 2 : math.min(stations - 2, 4),
          ),
          _RouteNode(
            label: 'Tujuan',
            name: data.destinationName,
            isFirst: false,
            fontSize: story ? 28 : 24,
          ),
          const Spacer(),
          if (duration != null) ...<Widget>[
            Text(
              formatDuration(duration),
              maxLines: 1,
              style: _style(
                story ? 64 : 52,
                weight: FontWeight.w800,
                letterSpacing: -1.5,
                height: 1.05,
                tabular: true,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Waktu tempuh',
              style: _style(13, color: ShareCardPalette.soft),
            ),
            SizedBox(height: story ? 28 : 20),
          ],
          Container(height: 1, color: ShareCardPalette.hairline),
          const SizedBox(height: 14),
          _FactsRow(facts: facts),
        ],
      ),
    );
  }
}

Widget _factColumn((String, String) fact) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        fact.$1.toUpperCase(),
        maxLines: 1,
        style: _style(
          10,
          weight: FontWeight.w800,
          color: ShareCardPalette.soft,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        fact.$2,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _style(14, weight: FontWeight.w700, tabular: true),
      ),
    ],
  );
}

class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.facts});

  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < facts.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 24),
          // Short facts keep their natural width so a date never wraps; the
          // line name takes whatever is left.
          if (facts[i].$1 == 'Jalur')
            Flexible(child: _factColumn(facts[i]))
          else
            _factColumn(facts[i]),
        ],
      ],
    );
  }
}

/// One station of the route motif: a dot, the join line below it (first) or
/// above it (last), and the station name. Heights follow the text, so long
/// names never overflow.
class _RouteNode extends StatelessWidget {
  const _RouteNode({
    required this.label,
    required this.name,
    required this.isFirst,
    required this.fontSize,
  });

  final String label;
  final String name;
  final bool isFirst;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Dot centre sits on the first line of the name.
    final dotY = 15 + fontSize * 0.56;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 28,
            child: CustomPaint(
              painter: _NodeDotPainter(isDestination: !isFirst, dotY: dotY),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label.toUpperCase(),
                  style: _style(
                    10,
                    weight: FontWeight.w800,
                    color: ShareCardPalette.soft,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _style(
                    fontSize,
                    weight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeDotPainter extends CustomPainter {
  const _NodeDotPainter({required this.isDestination, required this.dotY});

  final bool isDestination;
  final double dotY;

  @override
  void paint(Canvas canvas, Size size) {
    const x = 8.0;
    final center = Offset(x, dotY);
    final line = Paint()
      ..color = ShareCardPalette.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.butt;
    // The join line runs from the dot to the edge that faces the other node.
    if (isDestination) {
      canvas.drawLine(const Offset(x, 0), center, line);
      canvas.drawCircle(center, 9, Paint()..color = ShareCardPalette.white);
      canvas.drawCircle(center, 6, Paint()..color = ShareCardPalette.red);
    } else {
      canvas.drawLine(center, Offset(x, size.height), line);
      canvas.drawCircle(center, 7, Paint()..color = ShareCardPalette.white);
      canvas.drawCircle(center, 3, Paint()..color = ShareCardPalette.navy);
    }
  }

  @override
  bool shouldRepaint(_NodeDotPainter old) =>
      old.isDestination != isDestination || old.dotY != dotY;
}

/// The line between origin and destination with a few small stop dots. The
/// dot count only hints at length; it is capped and never printed as a number.
class _RouteConnector extends StatelessWidget {
  const _RouteConnector({required this.height, required this.midDots});

  final double height;
  final int midDots;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: height,
      child: CustomPaint(
        painter: _ConnectorPainter(midDots: math.max(0, midDots)),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({required this.midDots});

  final int midDots;

  @override
  void paint(Canvas canvas, Size size) {
    const x = 8.0;
    final line = Paint()
      ..color = ShareCardPalette.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(x, 0), Offset(x, size.height), line);
    if (midDots == 0) {
      return;
    }
    final step = size.height / (midDots + 1);
    for (var i = 1; i <= midDots; i++) {
      final center = Offset(x, step * i);
      canvas.drawCircle(center, 4.5, Paint()..color = ShareCardPalette.navy);
      canvas.drawCircle(center, 3, Paint()..color = ShareCardPalette.soft);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) => old.midDots != midDots;
}

/// "Rekap perjalanan": period, trip count as the focal number, total time,
/// favourite route and a weekday bar chart. Each block exists only when its
/// value does.
class RecapShareCard extends StatelessWidget {
  const RecapShareCard({required this.data, required this.aspect, super.key});

  final RecapShareData data;
  final ShareAspect aspect;

  @override
  Widget build(BuildContext context) {
    final story = aspect.isStory;
    final time = data.visibleTotalTime;
    final route = data.visibleTopRoute;
    final hasChart = data.tripsByWeekday.values.any((count) => count > 0);
    final range = data.rangeLabel;

    return _CardShell(
      aspect: aspect,
      semanticsLabel: data.caption,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Header(tag: 'REKAP PERJALANAN'),
          const Spacer(flex: 3),
          Container(
            width: 28,
            height: 4,
            decoration: BoxDecoration(
              color: ShareCardPalette.red,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.periodLabel,
            maxLines: 1,
            style: _style(20, weight: FontWeight.w800, letterSpacing: -0.3),
          ),
          if (range != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              range,
              maxLines: 1,
              style: _style(13, color: ShareCardPalette.soft),
            ),
          ],
          SizedBox(height: story ? 14 : 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  '${data.tripCount}',
                  maxLines: 1,
                  style: _style(
                    story ? 96 : 80,
                    weight: FontWeight.w800,
                    letterSpacing: -4,
                    height: 1,
                    tabular: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'perjalanan',
                style: _style(18, color: ShareCardPalette.soft),
              ),
            ],
          ),
          SizedBox(height: story ? 20 : 14),
          if (time != null || route != null) ...<Widget>[
            Container(height: 1, color: ShareCardPalette.hairline),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (time != null)
                  Expanded(
                    flex: 4,
                    child: _Fact(
                      label: 'Di kereta',
                      value: formatDuration(time),
                    ),
                  ),
                if (time != null && route != null) const SizedBox(width: 20),
                if (route != null)
                  Expanded(
                    flex: 6,
                    child: _Fact(
                      label: 'Rute tersering',
                      value: route,
                      maxLines: 2,
                    ),
                  ),
              ],
            ),
          ],
          if (hasChart) ...<Widget>[
            SizedBox(height: story ? 24 : 16),
            SizedBox(
              height: story ? 110 : 88,
              child: CustomPaint(
                size: Size.infinite,
                painter: WeekdayBarsPainter(counts: data.tripsByWeekday),
              ),
            ),
          ],
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.maxLines = 1});

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          maxLines: 1,
          style: _style(
            10,
            weight: FontWeight.w800,
            color: ShareCardPalette.soft,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: _style(15, weight: FontWeight.w700, tabular: true),
        ),
      ],
    );
  }
}

/// Mon-Sun bars drawn on a canvas. Every non-empty bar carries its count and
/// every bar a day label, so the busiest day (solid white against dimmed
/// bars) is also readable as text and never depends on colour alone.
class WeekdayBarsPainter extends CustomPainter {
  WeekdayBarsPainter({required this.counts});

  /// Trip count per `DateTime.weekday`; missing days are zero.
  final Map<int, int> counts;

  static const _shortNames = <String>[
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 16.0;
    const valueHeight = 16.0;
    final chartHeight = math.max(
      0.0,
      size.height - labelHeight - valueHeight - 6,
    );
    final maxCount = counts.values.fold<int>(0, math.max);
    final busiest = busiestWeekday(counts);
    final slot = size.width / 7;
    final barWidth = math.min(28.0, slot * 0.56);
    final baseline = valueHeight + chartHeight;

    for (var i = 0; i < 7; i++) {
      final weekday = DateTime.monday + i;
      final count = counts[weekday] ?? 0;
      final isBusiest = weekday == busiest;
      final centerX = slot * i + slot / 2;
      final barHeight = maxCount == 0 || count == 0
          ? 0.0
          : math.max(6.0, chartHeight * count / maxCount);

      final rect = Rect.fromLTWH(
        centerX - barWidth / 2,
        baseline - (count == 0 ? 2 : barHeight),
        barWidth,
        count == 0 ? 2 : barHeight,
      );
      final rrect = count == 0
          ? RRect.fromRectAndRadius(rect, const Radius.circular(1))
          : RRect.fromRectAndCorners(
              rect,
              topLeft: const Radius.circular(4),
              topRight: const Radius.circular(4),
            );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = count == 0
              ? ShareCardPalette.hairline
              : isBusiest
              ? ShareCardPalette.white
              : ShareCardPalette.barDim,
      );

      if (count > 0) {
        _paintText(
          canvas,
          '$count',
          Offset(centerX, rect.top - 4),
          _style(
            12,
            weight: isBusiest ? FontWeight.w800 : FontWeight.w600,
            color: isBusiest ? ShareCardPalette.white : ShareCardPalette.soft,
            tabular: true,
          ),
          anchorBottom: true,
        );
      }
      _paintText(
        canvas,
        _shortNames[i],
        Offset(centerX, baseline + 6),
        _style(
          11,
          weight: isBusiest ? FontWeight.w800 : FontWeight.w600,
          color: isBusiest ? ShareCardPalette.white : ShareCardPalette.soft,
        ),
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset anchor,
    TextStyle style, {
    bool anchorBottom = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final dy = anchorBottom ? anchor.dy - painter.height : anchor.dy;
    painter.paint(canvas, Offset(anchor.dx - painter.width / 2, dy));
  }

  @override
  bool shouldRepaint(WeekdayBarsPainter old) => !mapEquals(old.counts, counts);
}
