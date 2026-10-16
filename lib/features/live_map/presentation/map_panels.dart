import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import 'live_map_geometry.dart';
import 'map_points_layer.dart';

/// Floating search field. Opens [showStationSearchSheet]; it is also the
/// accessible way to pick a station, since the stations on the canvas are not
/// individual widgets.
class MapSearchField extends StatelessWidget {
  const MapSearchField({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      button: true,
      label: 'Cari stasiun',
      excludeSemantics: true,
      child: Material(
        color: tk.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TkRadius.control),
          side: BorderSide(color: tk.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(TkRadius.control),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: <Widget>[
                  Icon(Icons.search_rounded, color: tk.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cari stasiun',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: tk.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal line filter: "Semua" plus one chip per line, each with its map
/// colour so the chip doubles as the legend.
class MapLineChips extends StatelessWidget {
  const MapLineChips({
    required this.lineIds,
    required this.lineColors,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<String> lineIds;
  final Map<String, Color> lineColors;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: lineIds.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _LineChip(
              label: 'Semua',
              selected: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final id = lineIds[index - 1];
          return _LineChip(
            label: lineShortName(id),
            color: lineColors[id],
            selected: selected == id,
            onTap: () => onSelected(selected == id ? null : id),
          );
        },
      ),
    );
  }
}

class _LineChip extends StatelessWidget {
  const _LineChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      button: true,
      selected: selected,
      label: label == 'Semua' ? 'Semua lintas' : 'Lintas $label',
      excludeSemantics: true,
      child: Center(
        child: Material(
          color: selected ? tk.primary : tk.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TkRadius.control),
            side: BorderSide(color: selected ? tk.primary : tk.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(TkRadius.control),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (color != null) ...<Widget>[
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? tk.onPrimary : tk.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? tk.onPrimary : tk.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zoom and "my location" buttons, every one 48dp.
class MapControls extends StatelessWidget {
  const MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocate,
    required this.locating,
    super.key,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocate;
  final bool locating;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    ShapeBorder shape() => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TkRadius.control),
      side: BorderSide(color: tk.border),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: tk.surface,
          shape: shape(),
          child: IconButton(
            tooltip: 'Lokasi saya',
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            onPressed: locating ? null : onLocate,
            icon: locating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tk.primary,
                    ),
                  )
                : Icon(Icons.my_location_rounded, color: tk.primary),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: tk.surface,
          shape: shape(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Perbesar',
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                onPressed: onZoomIn,
                icon: Icon(Icons.add_rounded, color: tk.text),
              ),
              Divider(height: 1, color: tk.border),
              IconButton(
                tooltip: 'Perkecil',
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                onPressed: onZoomOut,
                icon: Icon(Icons.remove_rounded, color: tk.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown when base-map tiles keep failing. Lines and stations are drawn by the
/// app itself, so the map stays usable; the banner just says why it is plain.
class MapTileErrorBanner extends StatelessWidget {
  const MapTileErrorBanner({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TkCard(
        tone: TkCardTone.warning,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: <Widget>[
            Icon(Icons.cloud_off_rounded, color: tk.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Peta dasar belum bisa dimuat. Jalur dan stasiun tetap tampil.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet-style panel for the selected station or train.
class MapSelectionPanel extends StatelessWidget {
  const MapSelectionPanel({
    required this.selection,
    required this.lineColors,
    required this.stationsByCode,
    required this.onClose,
    super.key,
  });

  final MapSelection selection;
  final Map<String, Color> lineColors;
  final Map<String, Station> stationsByCode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tk.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(TkRadius.sheet),
          ),
          border: Border(top: BorderSide(color: tk.border)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: tk.text.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
            child: switch (selection) {
              StationSelection(:final station) => _StationPanel(
                station: station,
                lineColors: lineColors,
                onClose: onClose,
              ),
              VehicleSelection(:final vehicle) => _VehiclePanel(
                vehicle: vehicle,
                stationsByCode: stationsByCode,
                onClose: onClose,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.onClose,
    this.subtitle,
  });

  final String title;
  final Widget? subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 6),
                  subtitle!,
                ],
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Tutup',
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _StationPanel extends ConsumerWidget {
  const _StationPanel({
    required this.station,
    required this.lineColors,
    required this.onClose,
  });

  final Station station;
  final Map<String, Color> lineColors;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final text = Theme.of(context).textTheme;
    final departures = ref.watch(departuresProvider(station.id));
    final now = ref.watch(clockProvider).now();
    final lineIds = <String>{
      for (final id in station.lineIds) canonicalLineId(id),
    }.toList()..sort();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PanelHeader(
          title: station.name,
          onClose: onClose,
          subtitle: lineIds.isEmpty
              ? null
              : Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final id in lineIds)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 14,
                            height: 4,
                            decoration: BoxDecoration(
                              color: lineColors[id] ?? tk.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            lineShortName(id),
                            style: text.bodySmall?.copyWith(
                              color: tk.textMuted,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Text(
          'Kereta berikutnya',
          style: text.labelMedium?.copyWith(color: tk.textMuted),
        ),
        const SizedBox(height: 4),
        departures.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: <Widget>[
                TkSkeleton(height: 20),
                SizedBox(height: 10),
                TkSkeleton(height: 20),
                SizedBox(height: 10),
                TkSkeleton(height: 20),
              ],
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Jadwal belum bisa dimuat.',
                    style: text.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(departuresProvider(station.id)),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
          data: (items) {
            final upcoming =
                items
                    .where(
                      (d) => d.expectedAt.isAfter(
                        now.subtract(const Duration(minutes: 1)),
                      ),
                    )
                    .toList()
                  ..sort((a, b) => a.expectedAt.compareTo(b.expectedAt));
            if (upcoming.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Belum ada keberangkatan terjadwal dari stasiun ini dalam waktu dekat.',
                  style: text.bodyMedium,
                ),
              );
            }
            return Column(
              children: <Widget>[
                for (final d in upcoming.take(3))
                  _DepartureRow(departure: d, now: now),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: () => context.push('/station/${station.id}'),
                  child: const Text('Detail stasiun'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/explore?station=${station.id}'),
                  child: const Text('Sekitar stasiun'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DepartureRow extends StatelessWidget {
  const _DepartureRow({required this.departure, required this.now});

  final Departure departure;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final text = Theme.of(context).textTheme;
    final wait = departure.expectedAt.difference(now);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 58,
            child: Text(
              formatClock(departure.expectedAt.toLocal()),
              style: text.titleMedium?.copyWith(
                fontFeatures: AppTheme.timeFeatures,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Ke ${departure.destination}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (departure.lineName.isNotEmpty)
                  Text(
                    departure.lineName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: tk.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatWait(wait),
            style: text.labelLarge?.copyWith(
              color: tk.primary,
              fontFeatures: AppTheme.timeFeatures,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehiclePanel extends StatelessWidget {
  const _VehiclePanel({
    required this.vehicle,
    required this.stationsByCode,
    required this.onClose,
  });

  final VehiclePosition vehicle;
  final Map<String, Station> stationsByCode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final text = Theme.of(context).textTheme;
    final next = vehicle.nextStationId == null
        ? null
        : stationsByCode[vehicle.nextStationId];
    final speed = vehicle.speedMetersPerSecond;
    final basis = switch (vehicle.freshness) {
      DataFreshness.realtime => 'Posisi dari data kereta langsung.',
      DataFreshness.nearRealtime =>
        'Posisi dari laporan penumpang di kereta ini, tertunda beberapa saat.',
      DataFreshness.scheduled ||
      DataFreshness.estimated =>
        'Posisi ini dihitung dari jadwal, bukan dari GPS kereta.',
      DataFreshness.unavailable => 'Sumber posisi belum jelas.',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PanelHeader(
          title: next == null ? 'Posisi kereta' : 'Menuju ${next.name}',
          onClose: onClose,
          subtitle: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              DataFreshnessBadge(freshness: vehicle.freshness, compact: true),
              Text(
                'Diperbarui ${relativeTime(vehicle.recordedAt).toLowerCase()}',
                style: text.bodySmall?.copyWith(color: tk.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(basis, style: text.bodyMedium),
        ),
        if (speed != null && speed > 0) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Kecepatan ${formatSpeedKmh(speed * 3.6)}',
            style: text.bodySmall?.copyWith(color: tk.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Searchable station list. Returns the chosen station.
Future<Station?> showStationSearchSheet(
  BuildContext context, {
  required List<Station> stations,
  required Map<String, Color> lineColors,
}) {
  return showModalBottomSheet<Station>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.tk.surface,
    builder: (sheetContext) =>
        _StationSearchSheet(stations: stations, lineColors: lineColors),
  );
}

class _StationSearchSheet extends StatefulWidget {
  const _StationSearchSheet({required this.stations, required this.lineColors});

  final List<Station> stations;
  final Map<String, Color> lineColors;

  @override
  State<_StationSearchSheet> createState() => _StationSearchSheetState();
}

class _StationSearchSheetState extends State<_StationSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final results = searchStations(widget.stations, _query);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari stasiun',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _query = ''),
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Tidak ada stasiun bernama "$_query".',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: tk.textMuted),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final s = results[index];
                        final ids = <String>{
                          for (final id in s.lineIds) canonicalLineId(id),
                        }.toList()..sort();
                        return ListTile(
                          minTileHeight: 56,
                          leading: Icon(Icons.train_rounded, color: tk.primary),
                          title: Text(s.name),
                          subtitle: ids.isEmpty
                              ? null
                              : Text(ids.map(lineShortName).join(', ')),
                          onTap: () => Navigator.of(context).pop(s),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
