import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';

class LiveMapPage extends ConsumerWidget {
  const LiveMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(stationListProvider);
    final vehicles = ref.watch(vehiclePositionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta perjalanan'),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: DataFreshnessBadge(
                freshness: DataFreshness.estimated,
                compact: true,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: stations.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const AppEmptyState(
            icon: Icons.map_outlined,
            title: 'Peta belum tersedia',
            message: 'Data jalur lokal tidak dapat dimuat.',
          ),
          data: (items) {
            final visible = items
                .where(
                  (station) => const <String>{
                    'BOO',
                    'CTA',
                    'DP',
                    'UI',
                    'PSM',
                    'MRI',
                    'SUD',
                    'GDD',
                    'JAKK',
                  }.contains(station.id),
                )
                .toList(growable: false);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: <Widget>[
                const DemoDataBanner(),
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        color: AppColors.navy,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                        child: const Row(
                          children: <Widget>[
                            Icon(
                              Icons.alt_route_rounded,
                              color: AppColors.softBlue,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Skema rel lokal',
                                style: TextStyle(
                                  color: AppColors.surfaceLight,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              'bukan GPS langsung',
                              style: TextStyle(
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        image: true,
                        label:
                            'Diagram jalur demo dari Bogor menuju Jakarta Kota, dengan percabangan ke Sudirman.',
                        child: SizedBox(
                          height: 360,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _RailDiagramPainter(
                              brightness: Theme.of(context).brightness,
                              hasEstimatedVehicle: vehicles.value?.isNotEmpty ?? false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.info_outline_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Posisi kereta adalah simulasi berbasis jadwal. Aplikasi tidak mengklaim data operasional real-time.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Stasiun pada skema',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                for (final station in visible)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(station.code)),
                      title: Text(station.name),
                      subtitle: Text(
                        station.lineIds.map((line) => 'Lintas $line').join(' • '),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/station/${station.id}'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RailDiagramPainter extends CustomPainter {
  const _RailDiagramPainter({
    required this.brightness,
    required this.hasEstimatedVehicle,
  });

  final Brightness brightness;
  final bool hasEstimatedVehicle;

  @override
  void paint(Canvas canvas, Size size) {
    final muted = brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final origin = Offset(size.width * 0.28, 32);
    final end = Offset(size.width * 0.28, size.height - 34);
    final rail = Paint()
      ..color = AppColors.blue
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final branch = Paint()
      ..color = AppColors.coral
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final node = Paint()..color = AppColors.surfaceLight;
    final nodeBorder = Paint()
      ..color = AppColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawLine(origin, end, rail);
    final branchStart = Offset(size.width * 0.28, size.height * 0.62);
    final branchEnd = Offset(size.width * 0.74, size.height * 0.76);
    final path = Path()
      ..moveTo(branchStart.dx, branchStart.dy)
      ..cubicTo(
        size.width * 0.46,
        size.height * 0.62,
        size.width * 0.54,
        size.height * 0.76,
        branchEnd.dx,
        branchEnd.dy,
      );
    canvas.drawPath(path, branch);

    const labels = <String>[
      'Bogor',
      'Citayam',
      'Depok',
      'UI',
      'Pasar Minggu',
      'Manggarai',
      'Gondangdia',
      'Jakarta Kota',
    ];
    for (var index = 0; index < labels.length; index += 1) {
      final ratio = index / (labels.length - 1);
      final point = Offset(
        origin.dx,
        origin.dy + ((end.dy - origin.dy) * ratio),
      );
      canvas
        ..drawCircle(point, 8, node)
        ..drawCircle(point, 8, nodeBorder);
      final text = TextPainter(
        text: TextSpan(
          text: labels[index],
          style: TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: index == 0 || index == labels.length - 1
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.55);
      text.paint(canvas, point + const Offset(18, -8));
    }

    canvas
      ..drawCircle(branchEnd, 8, node)
      ..drawCircle(branchEnd, 8, nodeBorder);
    final sudirman = TextPainter(
      text: TextSpan(
        text: 'Sudirman',
        style: TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sudirman.paint(canvas, branchEnd + const Offset(-22, 15));

    if (hasEstimatedVehicle) {
      final trainPoint = Offset(
        origin.dx,
        origin.dy + ((end.dy - origin.dy) * 0.44),
      );
      canvas.drawCircle(trainPoint, 15, Paint()..color = AppColors.coral);
      final icon = TextPainter(
        text: const TextSpan(
          text: '●',
          style: TextStyle(color: AppColors.surfaceLight, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      icon.paint(
        canvas,
        trainPoint - Offset(icon.width / 2, icon.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RailDiagramPainter oldDelegate) {
    return oldDelegate.brightness != brightness ||
        oldDelegate.hasEstimatedVehicle != hasEstimatedVehicle;
  }
}
