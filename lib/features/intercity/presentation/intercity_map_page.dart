import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../active_trip/presentation/active_trip_controller.dart';
import '../../live_map/presentation/map_tiles.dart';
import '../data/intercity_repository.dart';
import '../domain/intercity_geometry.dart';
import '../domain/intercity_models.dart';
import '../domain/intercity_trip.dart';
import 'trip_mode.dart';

/// How well a train's route is known, measured on the data itself.
class RoutePrecision {
  const RoutePrecision({
    required this.maxStopOffsetMeters,
    required this.averageStopOffsetMeters,
    required this.stopCount,
    required this.verifiedStations,
  });

  factory RoutePrecision.of(
    IntercityService service,
    IntercityCatalog catalog,
  ) {
    final index = TrackIndex(service);
    var max = 0.0;
    var sum = 0.0;
    var verified = 0;
    for (final stop in service.stops) {
      final station = catalog.stations[stop.code]!;
      final offset = index
          .project(station.latitude, station.longitude, hintKm: stop.km)
          .offsetMeters;
      max = math.max(max, offset);
      sum += offset;
      if (station.coordinateStatus == 'verified') verified += 1;
    }
    return RoutePrecision(
      maxStopOffsetMeters: max,
      averageStopOffsetMeters: sum / service.stops.length,
      stopCount: service.stops.length,
      verifiedStations: verified,
    );
  }

  /// Distance from the farthest station to the drawn track.
  final double maxStopOffsetMeters;
  final double averageStopOffsetMeters;
  final int stopCount;

  /// Stations whose coordinate two independent sources agree on.
  final int verifiedStations;
}

/// The map of the Antar Kota mode: pick a train by name and see the track it
/// runs on and where it stops, with a plain account of how precise that is.
class IntercityMapPage extends ConsumerStatefulWidget {
  const IntercityMapPage({super.key});

  @override
  ConsumerState<IntercityMapPage> createState() => _IntercityMapPageState();
}

class _IntercityMapPageState extends ConsumerState<IntercityMapPage> {
  final MapController _controller = MapController();
  String? _serviceId;
  String? _selectedStop;
  bool _seededFromTrip = false;
  bool _detailsOpen = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(IntercityService service) {
    setState(() {
      _serviceId = service.id;
      _selectedStop = null;
      _detailsOpen = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit(service));
  }

  void _fit(IntercityService service) {
    if (!mounted || service.path.length < 2) return;
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(<LatLng>[
          for (final p in service.path) LatLng(p.latitude, p.longitude),
        ]),
        padding: const EdgeInsets.fromLTRB(36, 200, 36, 270),
        maxZoom: 13,
      ),
    );
  }

  Future<void> _pickTrain(IntercityCatalog catalog) async {
    final picked = await showModalBottomSheet<IntercityService>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) =>
          _TrainSheet(catalog: catalog, selectedId: _serviceId),
    );
    if (picked != null) _select(picked);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final catalogAsync = ref.watch(intercityCatalogProvider);
    return Scaffold(
      backgroundColor: tk.bg,
      body: catalogAsync.when(
        loading: () => const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: TkSkeleton(height: 320, radius: TkRadius.card),
          ),
        ),
        error: (error, stack) => const SafeArea(
          child: AppEmptyState(
            icon: Icons.map_outlined,
            title: 'Peta antar kota belum bisa dibuka',
            message: 'Data kereta antar kota belum bisa dimuat.',
          ),
        ),
        data: _buildMap,
      ),
    );
  }

  Widget _buildMap(IntercityCatalog catalog) {
    final tk = context.tk;
    // Open on the train of a ride in progress.
    if (!_seededFromTrip) {
      _seededFromTrip = true;
      final trip = ref.read(activeTripControllerProvider)?.trip;
      final tripRef = trip == null ? null : IntercityTripRef.tryParse(trip.id);
      final service = tripRef == null
          ? null
          : (tripRef.isCustom
                ? catalog.serviceForCustomRide(
                    tripRef.boardingCode,
                    tripRef.destinationCode,
                  )
                : catalog.serviceById(tripRef.serviceId));
      if (service != null) {
        _serviceId = service.id;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fit(service));
      }
    }
    final service = _serviceId == null
        ? null
        : catalog.serviceById(_serviceId!);
    final points = service == null
        ? const <LatLng>[]
        : <LatLng>[
            for (final p in service.path) LatLng(p.latitude, p.longitude),
          ];

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: const LatLng(-7.2, 109.5),
            initialZoom: 7,
            minZoom: 5,
            maxZoom: 18,
            backgroundColor: tk.surfaceAlt,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: <Widget>[
            if (tk.isDark)
              ColorFiltered(
                colorFilter: MapTileSource.darkMutedTileFilter,
                child: _tiles(),
              )
            else
              _tiles(),
            if (points.length >= 2)
              PolylineLayer<Object>(
                polylines: <Polyline<Object>>[
                  Polyline<Object>(
                    points: points,
                    color: tk.primary,
                    strokeWidth: 5,
                    borderStrokeWidth: 2,
                    borderColor: Colors.white.withValues(
                      alpha: tk.isDark ? 0.85 : 0.95,
                    ),
                  ),
                ],
              ),
            if (service != null) _stopMarkers(service, catalog),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TripModeToggle(
                    selected: ref.watch(tripModeProvider),
                    onSelected: ref.read(tripModeProvider.notifier).select,
                  ),
                  const SizedBox(height: 8),
                  _TrainField(
                    service: service,
                    catalog: catalog,
                    onTap: () => _pickTrain(catalog),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: service == null
              ? const _HintCard()
              : _ServiceCard(
                  service: service,
                  catalog: catalog,
                  selectedStop: _selectedStop,
                  expanded: _detailsOpen,
                  onToggle: () => setState(() => _detailsOpen = !_detailsOpen),
                  onStopSelected: (code) =>
                      setState(() => _selectedStop = code),
                ),
        ),
        Positioned(
          left: 12,
          bottom: service == null ? 130 : (_detailsOpen ? 400 : 250),
          child: _ZoomButtons(
            onIn: () => _controller.move(
              _controller.camera.center,
              _controller.camera.clampZoom(_controller.camera.zoom + 1),
            ),
            onOut: () => _controller.move(
              _controller.camera.center,
              _controller.camera.clampZoom(_controller.camera.zoom - 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tiles() => TileLayer(
    urlTemplate: MapTileSource.urlTemplate,
    userAgentPackageName: 'id.temankereta.teman_kereta',
    tileProvider: ref.read(mapTileProviderProvider),
    maxNativeZoom: 19,
    maxZoom: 18,
    keepBuffer: 2,
    panBuffer: 1,
    tileDisplay: const TileDisplay.instantaneous(),
  );

  Widget _stopMarkers(IntercityService service, IntercityCatalog catalog) {
    final tk = context.tk;
    final last = service.stops.length - 1;
    return MarkerLayer(
      markers: <Marker>[
        for (var i = 0; i < service.stops.length; i += 1)
          if (catalog.stations[service.stops[i].code] case final station?)
            Marker(
              point: LatLng(station.latitude, station.longitude),
              width: i == 0 || i == last ? 150 : 28,
              height: i == 0 || i == last ? 44 : 28,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    setState(() => _selectedStop = service.stops[i].code),
                child: _StopDot(
                  label: i == 0 || i == last ? station.name : null,
                  endpoint: i == 0 || i == last,
                  selected: _selectedStop == service.stops[i].code,
                  needsReview: station.coordinateStatus != 'verified',
                  color: tk.primary,
                ),
              ),
            ),
      ],
    );
  }
}

class _StopDot extends StatelessWidget {
  const _StopDot({
    required this.label,
    required this.endpoint,
    required this.selected,
    required this.needsReview,
    required this.color,
  });

  final String? label;
  final bool endpoint;
  final bool selected;
  final bool needsReview;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final dot = Container(
      width: selected ? 20 : (endpoint ? 18 : 14),
      height: selected ? 20 : (endpoint ? 18 : 14),
      decoration: BoxDecoration(
        color: endpoint ? color : tk.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: needsReview ? tk.warning : color,
          width: selected ? 4 : 3,
        ),
      ),
    );
    if (label == null) return Center(child: dot);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        dot,
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: tk.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tk.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrainField extends StatelessWidget {
  const _TrainField({
    required this.service,
    required this.catalog,
    required this.onTap,
  });

  final IntercityService? service;
  final IntercityCatalog catalog;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label:
          'Kereta: ${service?.name ?? 'belum dipilih'}. Ketuk untuk mengganti.',
      excludeSemantics: true,
      child: Material(
        color: tk.surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(TkRadius.control),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: <Widget>[
                  Icon(Icons.train_rounded, color: tk.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          service?.name ?? 'Pilih kereta',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium,
                        ),
                        if (service != null)
                          Text(
                            service!.routeLabel(catalog.stations),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: tk.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, color: tk.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: TkCard(
          child: Row(
            children: <Widget>[
              Icon(Icons.route_outlined, color: tk.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pilih nama kereta di atas untuk melihat jalur rel dan '
                  'stasiun pemberhentiannya.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomButtons extends StatelessWidget {
  const _ZoomButtons({required this.onIn, required this.onOut});

  final VoidCallback onIn;
  final VoidCallback onOut;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget button(IconData icon, String tooltip, VoidCallback onTap) =>
        Material(
          color: tk.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TkRadius.control),
            side: BorderSide(color: tk.border),
          ),
          child: IconButton(
            tooltip: tooltip,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            onPressed: onTap,
            icon: Icon(icon, color: tk.primary),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        button(Icons.add_rounded, 'Perbesar', onIn),
        const SizedBox(height: 8),
        button(Icons.remove_rounded, 'Perkecil', onOut),
      ],
    );
  }
}

/// The train's facts and how far to trust the route.
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.catalog,
    required this.selectedStop,
    required this.expanded,
    required this.onToggle,
    required this.onStopSelected,
  });

  final IntercityService service;
  final IntercityCatalog catalog;
  final String? selectedStop;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onStopSelected;

  static String _hours(double minutes) {
    final m = minutes.round();
    return m < 60
        ? '$m menit'
        : '${m ~/ 60} j ${(m % 60).toString().padLeft(2, '0')} m';
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final precision = RoutePrecision.of(service, catalog);
    final picked = selectedStop == null ? null : catalog.stations[selectedStop];
    final pickedStop = selectedStop == null
        ? null
        : service.stopAt(selectedStop!);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: TkCard(
          padding: const EdgeInsets.all(14),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.sizeOf(context).height * (expanded ? 0.5 : 0.34),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(service.name, style: textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    '${service.routeLabel(catalog.stations)} • '
                    '${service.totalKm.toStringAsFixed(0)} km • '
                    '${service.stops.length} pemberhentian',
                    style: textTheme.bodyMedium,
                  ),
                  if (service.classes.isNotEmpty)
                    Text(
                      service.classes.join(' • '),
                      style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Estimasi ${_hours(service.stops.last.estimatedMinutes)} '
                    '(bukan jadwal resmi)',
                    style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                  ),
                  if (picked != null && pickedStop != null) ...<Widget>[
                    const SizedBox(height: 10),
                    TkPill(
                      label:
                          '${picked.name} • km ${pickedStop.km.toStringAsFixed(0)}'
                          '${pickedStop.qualifier == null ? '' : ' • ${pickedStop.qualifier}'}',
                      icon: Icons.place_rounded,
                      tone: TkPillTone.primary,
                      dense: true,
                    ),
                  ],
                  const SizedBox(height: 10),
                  // One line is enough to judge the route; the detail is a tap away.
                  _Fact(
                    icon: service.verified
                        ? Icons.check_circle_outline_rounded
                        : Icons.warning_amber_rounded,
                    text: service.verified
                        ? 'Rute mengikuti rel (±${precision.maxStopOffsetMeters.round()} m), '
                              '${precision.verifiedStations}/${precision.stopCount} koordinat stasiun cocok di dua sumber.'
                        : 'Rute perkiraan: data rel di salah satu ruas janggal.',
                    warn:
                        !service.verified ||
                        precision.verifiedStations < precision.stopCount,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onToggle,
                      icon: Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                      ),
                      label: Text(
                        expanded
                            ? 'Sembunyikan detail'
                            : 'Seberapa tepat? Lihat detail dan pemberhentian',
                      ),
                    ),
                  ),
                  if (expanded) ...<Widget>[
                    Text(
                      'Seberapa tepat rute ini?',
                      style: textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    _Fact(
                      icon: Icons.timeline_rounded,
                      text: service.verified
                          ? 'Garis mengikuti rel dari OpenStreetMap, '
                                'disederhanakan sekitar 40 m. Tidak ada ruas '
                                'memutar atau rel yang dilewati dua kali.'
                          : 'Garis mengikuti rel dari OpenStreetMap, tapi data '
                                'rel di sekitar salah satu ruas janggal. Anggap '
                                'rute ini perkiraan.',
                      warn: !service.verified,
                    ),
                    _Fact(
                      icon: Icons.pin_drop_outlined,
                      text:
                          'Stasiun terjauh ${precision.maxStopOffsetMeters.round()} m '
                          'dari garis, rata-rata '
                          '${precision.averageStopOffsetMeters.round()} m.',
                    ),
                    _Fact(
                      icon: Icons.my_location_outlined,
                      text:
                          '${precision.verifiedStations} dari ${precision.stopCount} '
                          'koordinat stasiun cocok di dua sumber (OpenStreetMap '
                          'dan Wikidata). Titik kuning = hanya satu sumber atau '
                          'berbeda.',
                      warn: precision.verifiedStations < precision.stopCount,
                    ),
                    _Fact(
                      icon: Icons.fact_check_outlined,
                      text:
                          'Daftar pemberhentian dari Wikipedia (komunitas), bukan '
                          'data resmi KAI. Bisa ada stasiun yang terlewat atau '
                          'berhenti hanya di arah/jadwal tertentu.',
                      warn: true,
                    ),
                    const SizedBox(height: 10),
                    Text('Pemberhentian', style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    for (final stop in service.stops)
                      _StopRow(
                        name: catalog.stations[stop.code]?.name ?? stop.code,
                        place: catalog.stations[stop.code]?.placeLabel ?? '',
                        km: stop.km,
                        minutes: stop.estimatedMinutes,
                        note: stop.qualifier,
                        selected: stop.code == selectedStop,
                        onTap: () => onStopSelected(stop.code),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, this.warn = false});

  final IconData icon;
  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: warn ? tk.warning : tk.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.name,
    required this.place,
    required this.km,
    required this.minutes,
    required this.selected,
    required this.onTap,
    this.note,
  });

  final String name;
  final String place;
  final double km;
  final double minutes;
  final String? note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final m = minutes.round();
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        color: selected ? tk.primarySoft : null,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 52,
              child: Text(
                'km ${km.toStringAsFixed(0)}',
                style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name, style: textTheme.bodyMedium),
                  Text(
                    note == null ? place : '$place • $note',
                    style: textTheme.bodySmall?.copyWith(
                      color: note == null ? tk.textMuted : tk.warning,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '+${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}',
              style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainSheet extends StatefulWidget {
  const _TrainSheet({required this.catalog, required this.selectedId});

  final IntercityCatalog catalog;
  final String? selectedId;

  @override
  State<_TrainSheet> createState() => _TrainSheetState();
}

class _TrainSheetState extends State<_TrainSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final trains = widget.catalog.services.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final matches = trains
        .where(
          (s) =>
              query.isEmpty ||
              s.name.toLowerCase().contains(query) ||
              s
                  .routeLabel(widget.catalog.stations)
                  .toLowerCase()
                  .contains(query),
        )
        .toList(growable: false);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Pilih kereta',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Cari nama kereta atau kota',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? Center(
                    child: Text(
                      'Kereta "$_query" tidak ada di daftar.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final train = matches[index];
                      return ListTile(
                        leading: const Icon(Icons.train_outlined),
                        title: Text(train.name),
                        subtitle: Text(
                          '${train.routeLabel(widget.catalog.stations)} • '
                          '${train.totalKm.toStringAsFixed(0)} km',
                        ),
                        selected: train.id == widget.selectedId,
                        onTap: () => Navigator.pop(context, train),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
