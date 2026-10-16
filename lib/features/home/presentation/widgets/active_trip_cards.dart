import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/tk_components.dart';
import '../../../../data/providers/demo_data.dart';
import '../../../../domain/entities/active_trip.dart';
import '../../../../domain/entities/transit_models.dart';

/// Tappable summary of the trip in progress, shown above everything else.
class ActiveTripStatusCard extends StatelessWidget {
  const ActiveTripStatusCard({
    required this.session,
    required this.stations,
    required this.onTap,
    super.key,
  });

  final ActiveTripSession session;
  final List<Station> stations;
  final VoidCallback onTap;

  String _nameOf(String? id) {
    if (id == null) return '-';
    return stations.where((s) => s.id == id).firstOrNull?.name ??
        demoStations.where((s) => s.id == id).firstOrNull?.name ??
        id;
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final nextName = session.nextStationId == null
        ? 'Tiba di tujuan'
        : _nameOf(session.nextStationId);
    final currentName = _nameOf(session.currentStationId);
    final destinationName = _nameOf(session.trip.destinationStationId);
    final remainingTransfers = session.trip.transferBoundaries
        .where((b) => b.index >= session.currentStationIndex)
        .length;
    final nextTransferName = session.nextTransferBoundary == null
        ? null
        : _nameOf(session.trip.stationIds[session.nextTransferBoundary!.index]);
    final transferText = remainingTransfers == 0
        ? 'Tanpa transit lagi'
        : 'Transit $remainingTransfers kali lagi'
              '${nextTransferName == null ? '' : ', berikutnya di $nextTransferName'}';

    return TkCard(
      tone: TkCardTone.soft,
      onTap: onTap,
      semanticLabel:
          'Perjalanan sedang berlangsung. Stasiun berikutnya $nextName. '
          '${session.remainingStops} stasiun lagi menuju $destinationName. '
          'Ketuk untuk membuka.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.train_rounded, color: tk.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Perjalanan berlangsung',
                  style: textTheme.titleSmall?.copyWith(color: tk.primary),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: tk.textMuted),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Baru melewati $currentName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall,
          ),
          Text(
            'Berikutnya: $nextName',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${session.remainingStops} stasiun lagi menuju $destinationName',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
          Text(
            transferText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Quiet one-line note for the pre-boarding phases of ride detection.
class RideDetectionPhaseBanner extends StatelessWidget {
  const RideDetectionPhaseBanner({
    required this.label,
    super.key,
    this.stationName,
  });

  final String label;
  final String? stationName;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final text = stationName == null ? label : '$label $stationName';
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tk.surfaceAlt,
          borderRadius: BorderRadius.circular(TkRadius.control),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.sensors_rounded, size: 18, color: tk.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
