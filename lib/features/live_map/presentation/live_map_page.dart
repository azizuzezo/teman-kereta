import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../data/providers/rail_line_shapes.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/transit_network.dart';
import 'live_map_geometry.dart';
import 'live_trip_position_controller.dart';
import 'map_panels.dart';
import 'map_points_layer.dart';
import 'map_tiles.dart';

/// Live map of the KRL network.
///
/// Draws each line on its real track (OpenStreetMap rail geometry bundled in
/// `rail_line_shapes.dart`) in the line's own colour, stations as hollow dots,
/// estimated and reported train positions, and, during an active trip, the
/// rider's position. Tiles come from [MapTileSource] through a disk cache.
///
/// Why it is cheap to pan: the base layer is cached raster tiles; the track
/// layer is one stable `PolylineLayer` instance (flutter_map throws away its
/// projection cache every time it receives a *new* layer widget); stations,
/// trains and the rider are one canvas pass ([MapPointsLayer]) instead of
/// ~100 marker widgets; and selection, line filter and live positions each
/// update only their own layer through listenables instead of rebuilding the
/// page.
class LiveMapPage extends ConsumerWidget {
  const LiveMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(stationListProvider);
    return Scaffold(
      backgroundColor: context.tk.bg,
      body: stations.when(
        loading: () => const _MapLoading(),
        error: (error, stack) => SafeArea(
          child: TkErrorState(
            title: 'Peta belum bisa dibuka',
            message:
                'Data stasiun belum bisa dimuat. Periksa koneksi, lalu coba lagi.',
            onRetry: () => ref.invalidate(stationListProvider),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const SafeArea(
              child: AppEmptyState(
                icon: Icons.map_outlined,
                title: 'Peta belum tersedia',
                message: 'Belum ada data stasiun untuk digambar.',
              ),
            );
          }
          return _MapBody(stations: items);
        },
      ),
    );
  }
}

class _MapLoading extends StatelessWidget {
  const _MapLoading();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: <Widget>[
            TkSkeleton(height: 48, radius: TkRadius.control),
            SizedBox(height: 8),
            Row(
              children: <Widget>[
                TkSkeleton(height: 40, width: 72, radius: TkRadius.control),
                SizedBox(width: 8),
                TkSkeleton(height: 40, width: 96, radius: TkRadius.control),
                SizedBox(width: 8),
                TkSkeleton(height: 40, width: 96, radius: TkRadius.control),
              ],
            ),
            SizedBox(height: 12),
            Expanded(child: _FillSkeleton()),
          ],
        ),
      ),
    );
  }
}

class _FillSkeleton extends StatelessWidget {
  const _FillSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          TkSkeleton(height: constraints.maxHeight, radius: TkRadius.card),
    );
  }
}

class _MapBody extends ConsumerStatefulWidget {
  const _MapBody({required this.stations});

  final List<Station> stations;

  @override
  ConsumerState<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends ConsumerState<_MapBody> {
  static const _packageName = 'id.temankereta.teman_kereta';

  final MapController _mapController = MapController();
  final ValueNotifier<MapSelection?> _selection = ValueNotifier(null);
  final ValueNotifier<String?> _lineFilter = ValueNotifier(null);

  /// Which rail network the map is showing highlighted. Jabodetabek and
  /// Yogyakarta are ~440 km apart, so each tab frames its own network.
  late final ValueNotifier<TransitNetwork> _network;
  final ValueNotifier<LatLng?> _myLocation = ValueNotifier(null);
  final ValueNotifier<bool> _locating = ValueNotifier(false);
  final TileHealthTracker _tileHealth = TileHealthTracker();
  final StreamController<void> _tileReset = StreamController<void>.broadcast();

  late List<MapStationPoint> _points;
  late List<String> _lineIds;
  late List<LineTrack> _tracks;
  late Map<String, Station> _stationsByCode;
  late LatLngBounds _stationBounds;

  /// Networks that actually have stations, in tab order. Fewer than two means
  /// there is nothing to switch between and the tabs stay hidden.
  late List<TransitNetwork> _networks;
  late Map<TransitNetwork, List<MapStationPoint>> _pointsByNetwork;
  late Map<TransitNetwork, LatLngBounds> _boundsByNetwork;

  // Memoised so unrelated rebuilds hand flutter_map the very same layer
  // widgets (see class comment).
  Map<String, Color>? _colorsSource;
  bool? _colorsDark;
  Map<String, Color> _colors = const <String, Color>{};
  Object? _trackKey;
  Widget? _trackLayer;
  Widget? _tileLayer;

  @override
  void initState() {
    super.initState();
    _derive();
    _network = ValueNotifier<TransitNetwork>(
      _networks.contains(TransitNetwork.jabodetabek)
          ? TransitNetwork.jabodetabek
          : _networks.first,
    );
  }

  @override
  void didUpdateWidget(_MapBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.stations, widget.stations)) {
      _derive();
      _trackKey = null;
    }
  }

  void _derive() {
    final stations = widget.stations;
    _points = <MapStationPoint>[for (final s in stations) MapStationPoint(s)];
    _lineIds = lineIdsOf(stations);
    _tracks = <LineTrack>[
      for (final id in _lineIds)
        ?buildLineTrack(lineId: id, stations: stations, shapes: railLineShapes),
    ];
    _stationsByCode = <String, Station>{for (final s in stations) s.code: s};
    _stationBounds = LatLngBounds.fromPoints(<LatLng>[
      for (final p in _points) p.point,
    ]);
    _pointsByNetwork = <TransitNetwork, List<MapStationPoint>>{
      for (final network in TransitNetwork.values)
        network: <MapStationPoint>[
          for (final p in _points)
            if (networkOfStation(p.station) == network) p,
        ],
    }..removeWhere((_, points) => points.isEmpty);
    _networks = <TransitNetwork>[
      for (final network in TransitNetwork.values)
        if (_pointsByNetwork.containsKey(network)) network,
    ];
    _boundsByNetwork = <TransitNetwork, LatLngBounds>{
      for (final entry in _pointsByNetwork.entries)
        entry.key: LatLngBounds.fromPoints(<LatLng>[
          for (final p in entry.value) p.point,
        ]),
    };
  }

  /// The stations drawn and tappable for [network]; the whole list when the
  /// map has no network split (a single network, or a provider without lines).
  List<MapStationPoint> _pointsOf(TransitNetwork network) =>
      _pointsByNetwork[network] ?? _points;

  LatLngBounds _boundsOf(TransitNetwork network) =>
      _boundsByNetwork[network] ?? _stationBounds;

  List<String> _lineIdsOf(TransitNetwork network) {
    if (_networks.length < 2) return _lineIds;
    return <String>[
      for (final id in _lineIds)
        if (networkOfLineCode(id) == network) id,
    ];
  }

  void _selectNetwork(TransitNetwork network) {
    if (_network.value == network) return;
    _network.value = network;
    _lineFilter.value = null;
    _selection.value = null;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: _boundsOf(network),
        padding: const EdgeInsets.fromLTRB(32, 190, 32, 110),
        maxZoom: 13,
      ),
    );
  }

  @override
  void dispose() {
    _selection.dispose();
    _lineFilter.dispose();
    _network.dispose();
    _myLocation.dispose();
    _locating.dispose();
    _tileHealth.dispose();
    unawaited(_tileReset.close());
    _mapController.dispose();
    super.dispose();
  }

  Map<String, Color> _lineColorsFor(Map<String, Color> db, bool dark) {
    if (!identical(db, _colorsSource) || dark != _colorsDark) {
      _colorsSource = db;
      _colorsDark = dark;
      _colors = resolveLineColors(
        lineIds: _lineIds,
        dbColors: db,
        mapBackground: dark
            ? MapTileSource.darkBackgroundReference
            : MapTileSource.lightBackgroundReference,
      );
    }
    return _colors;
  }

  Widget _buildTileLayer() {
    return _tileLayer ??= TileLayer(
      urlTemplate: MapTileSource.urlTemplate,
      userAgentPackageName: _packageName,
      tileProvider: ref.read(mapTileProviderProvider),
      maxNativeZoom: 19,
      maxZoom: 18,
      keepBuffer: 2,
      panBuffer: 1,
      tileDisplay: const TileDisplay.instantaneous(),
      evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
      errorTileCallback: (tile, error, stackTrace) => _tileHealth.recordError(),
      reset: _tileReset.stream,
    );
  }

  Widget _buildTrackLayer(
    String? filter,
    TransitNetwork network,
    TkColors tk,
  ) {
    final key = Object.hash(
      filter,
      network,
      tk.isDark,
      identityHashCode(_colors),
      _tracks.length,
    );
    if (_trackLayer != null && _trackKey == key) {
      return _trackLayer!;
    }
    _trackKey = key;
    // A white outline keeps each line readable over the red/orange roads of
    // the base map and where parallel lines run side by side.
    final casing = Colors.white.withValues(alpha: tk.isDark ? 0.85 : 0.95);
    Polyline<Object> line(
      LineTrack track, {
      required bool dim,
      required bool bold,
    }) {
      final base = _colors[track.lineId] ?? tk.primary;
      return Polyline<Object>(
        points: track.points,
        color: dim ? base.withValues(alpha: 0.22) : base,
        strokeWidth: bold ? 6 : (dim ? 3 : 4.5),
        borderStrokeWidth: dim ? 0 : 2,
        borderColor: casing,
        pattern: track.isRealTrack
            ? const StrokePattern.solid()
            : StrokePattern.dashed(segments: const <double>[10, 8]),
      );
    }

    final dimmed = <Polyline<Object>>[];
    final normal = <Polyline<Object>>[];
    final split = _networks.length >= 2;
    for (final track in _tracks) {
      if (split && networkOfLineCode(track.lineId) != network) {
        // The other network: still on the map, but visibly in the background.
        dimmed.add(line(track, dim: true, bold: false));
      } else if (filter == null) {
        normal.add(line(track, dim: false, bold: false));
      } else if (track.lineId == filter) {
        normal.add(line(track, dim: false, bold: true));
      } else {
        dimmed.add(line(track, dim: true, bold: false));
      }
    }
    return _trackLayer = PolylineLayer<Object>(
      polylines: <Polyline<Object>>[...dimmed, ...normal],
    );
  }

  void _onMapTap(TapPosition position, LatLng latLng) {
    final tap = position.relative;
    if (tap == null) {
      return;
    }
    final vehicles = freshVehicles(
      ref.read(vehiclePositionsProvider).asData?.value ??
          const <VehiclePosition>[],
      DateTime.now(),
    );
    _selection.value = hitTestMapPoints(
      camera: _mapController.camera,
      tap: tap,
      stations: _pointsOf(_network.value),
      vehicles: vehicles,
      lineFilter: _lineFilter.value,
    );
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.clampZoom(camera.zoom + delta));
  }

  void _selectLine(String? lineId) {
    _lineFilter.value = lineId;
    final current = _selection.value;
    if (lineId != null &&
        current is StationSelection &&
        !stationIsOnLine(current.station, lineId)) {
      _selection.value = null;
    }
    final track = lineId == null
        ? null
        : _tracks.where((t) => t.lineId == lineId).firstOrNull;
    final bounds = track != null && track.points.isNotEmpty
        ? LatLngBounds.fromPoints(track.points)
        : _boundsOf(_network.value);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 150, 40, 120),
        maxZoom: 14,
      ),
    );
  }

  Future<void> _openSearch() async {
    final picked = await showStationSearchSheet(
      context,
      stations: widget.stations,
      lineColors: _colors,
    );
    if (picked == null || !mounted) {
      return;
    }
    // A station from the other network: switch tab first so it is drawn.
    if (_networks.length >= 2) {
      _selectNetwork(networkOfStation(picked));
    }
    final camera = _mapController.camera;
    _mapController.move(
      LatLng(picked.latitude, picked.longitude),
      math.max(camera.zoom, 14.5),
    );
    _selection.value = StationSelection(picked);
  }

  Future<bool> _explainLocation() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tampilkan lokasimu di peta?'),
        content: const Text(
          'Teman Kereta membaca lokasimu sekali, saat kamu menekan tombol ini, '
          'hanya untuk menunjukkan posisimu di peta. Lokasi tidak disimpan '
          'dan tidak dikirim ke mana pun.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Nanti saja'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _toast(String message, {SnackBarAction? action}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: action,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _goToMyLocation() async {
    if (_locating.value) {
      return;
    }
    _locating.value = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _toast(
          'Layanan lokasi di HP belum aktif.',
          action: SnackBarAction(
            label: 'Aktifkan',
            onPressed: () => unawaited(Geolocator.openLocationSettings()),
          ),
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!await _explainLocation() || !mounted) {
          return;
        }
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _toast(
          'Izin lokasi dimatikan. Aktifkan dari pengaturan aplikasi.',
          action: SnackBarAction(
            label: 'Buka pengaturan',
            onPressed: () => unawaited(Geolocator.openAppSettings()),
          ),
        );
        return;
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        _toast('Lokasi belum diizinkan, jadi posisimu belum bisa ditampilkan.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) {
        return;
      }
      final here = LatLng(position.latitude, position.longitude);
      _myLocation.value = here;
      _mapController.move(here, math.max(_mapController.camera.zoom, 15));
    } on Object {
      _toast('Lokasimu belum bisa dibaca. Coba lagi sebentar lagi.');
    } finally {
      _locating.value = false;
    }
  }

  void _retryTiles() {
    _tileHealth.reset();
    _tileReset.add(null);
  }

  Future<void> _openAttribution() async {
    try {
      await launchUrl(
        Uri.parse(MapTileSource.attributionUrl),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      // Nothing useful to show: the credit text itself is already visible.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final dbColors =
        ref.watch(lineColorsProvider).asData?.value ?? const <String, Color>{};
    final colors = _lineColorsFor(dbColors, tk.isDark);

    final tiles = _buildTileLayer();
    final startPoints = _pointsOf(_network.value);
    final initialFit = startPoints.length >= 2
        ? CameraFit.bounds(
            bounds: _boundsOf(_network.value),
            padding: EdgeInsets.fromLTRB(
              32,
              _networks.length >= 2 ? 190 : 150,
              32,
              110,
            ),
            maxZoom: 13,
          )
        : null;
    final constraintBounds = LatLngBounds(
      LatLng(_stationBounds.south - 0.4, _stationBounds.west - 0.4),
      LatLng(_stationBounds.north + 0.4, _stationBounds.east + 0.4),
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Semantics(
          label:
              'Peta jalur KRL. Untuk memilih stasiun, pakai kolom Cari stasiun.',
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: startPoints.first.point,
              initialZoom: 12,
              initialCameraFit: initialFit,
              minZoom: 9,
              maxZoom: 18,
              backgroundColor: tk.surfaceAlt,
              cameraConstraint: CameraConstraint.containCenter(
                bounds: constraintBounds,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: _onMapTap,
            ),
            children: <Widget>[
              if (tk.isDark)
                ColorFiltered(
                  colorFilter: MapTileSource.darkMutedTileFilter,
                  child: tiles,
                )
              else
                tiles,
              ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[
                  _lineFilter,
                  _network,
                ]),
                builder: (context, _) =>
                    _buildTrackLayer(_lineFilter.value, _network.value, tk),
              ),
              ValueListenableBuilder<TransitNetwork>(
                valueListenable: _network,
                builder: (context, network, _) => _PointsHost(
                  points: _pointsOf(network),
                  lineColors: colors,
                  lineFilter: _lineFilter,
                  selection: _selection,
                  myLocation: _myLocation,
                  colors: tk,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: MapSearchField(onTap: _openSearch),
                ),
                if (_networks.length >= 2)
                  ValueListenableBuilder<TransitNetwork>(
                    valueListenable: _network,
                    builder: (context, network, _) => MapNetworkTabs(
                      networks: _networks,
                      selected: network,
                      onSelected: _selectNetwork,
                    ),
                  ),
                if (_lineIds.isNotEmpty)
                  ListenableBuilder(
                    listenable: Listenable.merge(<Listenable>[
                      _lineFilter,
                      _network,
                    ]),
                    builder: (context, _) => MapLineChips(
                      lineIds: _lineIdsOf(_network.value),
                      lineColors: colors,
                      selected: _lineFilter.value,
                      onSelected: _selectLine,
                    ),
                  ),
                ListenableBuilder(
                  listenable: _tileHealth,
                  builder: (context, _) => _tileHealth.isDegraded
                      ? MapTileErrorBanner(onRetry: _retryTiles)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Flexible(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: _AttributionChip(onTap: _openAttribution),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: _locating,
                      builder: (context, locating, _) => MapControls(
                        onZoomIn: () => _zoomBy(1),
                        onZoomOut: () => _zoomBy(-1),
                        onLocate: _goToMyLocation,
                        locating: locating,
                      ),
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<MapSelection?>(
                valueListenable: _selection,
                builder: (context, selection, _) => selection == null
                    ? const SizedBox.shrink()
                    : MapSelectionPanel(
                        selection: selection,
                        lineColors: colors,
                        stationsByCode: _stationsByCode,
                        onClose: () => _selection.value = null,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rebuilds only the stations/trains/rider canvas when live data, selection or
/// filter change. A timer re-checks train freshness so a stale marker leaves
/// the map even when no new data arrives.
class _PointsHost extends ConsumerStatefulWidget {
  const _PointsHost({
    required this.points,
    required this.lineColors,
    required this.lineFilter,
    required this.selection,
    required this.myLocation,
    required this.colors,
  });

  final List<MapStationPoint> points;
  final Map<String, Color> lineColors;
  final ValueNotifier<String?> lineFilter;
  final ValueNotifier<MapSelection?> selection;
  final ValueNotifier<LatLng?> myLocation;
  final TkColors colors;

  @override
  ConsumerState<_PointsHost> createState() => _PointsHostState();
}

class _PointsHostState extends ConsumerState<_PointsHost> {
  Timer? _staleTimer;

  @override
  void initState() {
    super.initState();
    _staleTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _staleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = freshVehicles(
      ref.watch(vehiclePositionsProvider).asData?.value ??
          const <VehiclePosition>[],
      DateTime.now(),
    );
    final trip = ref.watch(liveTripPositionControllerProvider);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.lineFilter,
        widget.selection,
        widget.myLocation,
      ]),
      builder: (context, _) => MapPointsLayer(
        stations: widget.points,
        vehicles: vehicles,
        lineColors: widget.lineColors,
        lineFilter: widget.lineFilter.value,
        selection: widget.selection.value,
        myLocation: widget.myLocation.value,
        tripPosition: trip,
        colors: widget.colors,
      ),
    );
  }
}

class _AttributionChip extends StatelessWidget {
  const _AttributionChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      button: true,
      link: true,
      label: 'Hak cipta peta, ${MapTileSource.attributionText}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tk.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '© ${MapTileSource.attributionText}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: tk.textMuted),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
