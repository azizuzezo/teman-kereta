import 'package:flutter/material.dart';

import '../../domain/entities/transit_models.dart';

class TripLegTimelineTile extends StatelessWidget {
  const TripLegTimelineTile({required this.leg, required this.isLast, super.key});

  final TripLeg leg;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (icon, title) = switch (leg.mode) {
      TransportMode.walk => (Icons.directions_walk_rounded, 'Berjalan kaki'),
      TransportMode.commuterRail => (Icons.train_rounded, 'Naik Commuter Line'),
      TransportMode.mrt => (Icons.subway_rounded, 'Naik MRT'),
      TransportMode.lrt => (Icons.tram_rounded, 'Naik LRT'),
      TransportMode.bus => (Icons.directions_bus_rounded, 'Naik bus'),
      TransportMode.bicycle => (Icons.pedal_bike_rounded, 'Bersepeda'),
      TransportMode.rideHailing => (Icons.local_taxi_outlined, 'Transportasi online'),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              CircleAvatar(radius: 22, child: Icon(icon)),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text('${leg.originName} → ${leg.destinationName}'),
                  if (leg.lineName != null)
                    Text(
                      '${leg.lineName} • arah ${leg.headsign}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (leg.stationIds.isNotEmpty)
                    Text(
                      '${leg.stationIds.length} stasiun',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (leg.transferInstruction != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      leg.transferInstruction!,
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
