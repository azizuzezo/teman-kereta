import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/entities/transit_models.dart';
import 'tk_components.dart';

/// One step of a trip (walk, rail, ...) on the vertical route line shared by
/// trip detail and the multimodal page. The icon tile sits on the line, the
/// line runs down to the next step, and times use tabular figures.
class TripLegTimelineTile extends StatelessWidget {
  const TripLegTimelineTile({required this.leg, required this.isLast, super.key});

  final TripLeg leg;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final (icon, title) = switch (leg.mode) {
      TransportMode.walk => (Icons.directions_walk_rounded, 'Berjalan kaki'),
      TransportMode.commuterRail => (Icons.train_rounded, 'Naik Commuter Line'),
      TransportMode.mrt => (Icons.subway_rounded, 'Naik MRT'),
      TransportMode.lrt => (Icons.tram_rounded, 'Naik LRT'),
      TransportMode.bus => (Icons.directions_bus_rounded, 'Naik bus'),
      TransportMode.bicycle => (Icons.pedal_bike_rounded, 'Bersepeda'),
      TransportMode.rideHailing => (
        Icons.local_taxi_outlined,
        'Transportasi online',
      ),
    };
    final isRail = leg.mode == TransportMode.commuterRail;
    final time = DateFormat.Hm('id_ID');
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isRail ? tk.primary : tk.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isRail ? tk.onPrimary : tk.primary,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: tk.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: textTheme.titleSmall),
                  Text(
                    '${time.format(leg.departureAt)} – ${time.format(leg.arrivalAt)}',
                    style: textTheme.labelLarge?.copyWith(
                      color: tk.textMuted,
                      fontFeatures: AppTheme.timeFeatures,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${leg.originName} → ${leg.destinationName}',
                    style: textTheme.bodyMedium,
                  ),
                  if (leg.lineName != null)
                    Text(
                      '${leg.lineName} • arah ${leg.headsign}',
                      style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                    ),
                  if (leg.stationIds.isNotEmpty)
                    Text(
                      '${leg.stationIds.length} stasiun',
                      style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                    ),
                  if (leg.transferInstruction != null) ...<Widget>[
                    const SizedBox(height: 8),
                    TkCard(
                      tone: TkCardTone.warning,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.compare_arrows_rounded,
                            size: 18,
                            color: tk.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              leg.transferInstruction!,
                              style: textTheme.bodySmall?.copyWith(
                                color: tk.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
