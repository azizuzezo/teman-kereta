import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../data/providers/rail_line_shapes.dart';
import '../../../domain/entities/transit_models.dart';
import 'live_trip_position_controller.dart';

/// Real geographic live map: OpenStreetMap tiles with each KRL line drawn as
/// a polyline through its real stations (in real per-line stop order, via
/// `Station.stopOrderByLine`) plus station markers and, while an Active Trip
/// is on board, the rider's own approximate live position — see
/// `LiveTripPositionController`. Deliberately carries NO live-train-position
/// markers of any kind (that used to be a raster KAI map image and a
/// hand-drawn schematic with vehicle badges; both are gone).
class LiveMapPage extends ConsumerStatefulWidget {
  const LiveMapPage({super.key});

  @override
  ConsumerState<LiveMapPage> createState() => _LiveMapPageState();
}

class _LiveMapPageState extends ConsumerState<LiveMapPage> {
  final MapController _mapController = MapController();
  LatLng? _myLocation;
  bool _locatingMe = false;

  static const Map<String, String> _lineLabels = {
    'BOGOR': 'Lintas Bogor',
    'NAMBO': 'Lintas Bogor - Nambo (Cabang)',
    'CIKARANG': 'Lintas Cikarang',
    'RANGKASBITUNG': 'Lintas Rangkasbitung',
    'TANGERANG': 'Lintas Tangerang',
    'TANJUNG_PRIOK': 'Lintas Tanjung Priok',
    'BEKASI': 'Lintas Bekasi',
    'SERPONG': 'Lintas Serpong',
  };

  /// Used only when a line code has no matching row in `public.lines` (via
  /// [lineColorsProvider]) — should not normally happen since every real
  /// line is seeded there with its correct KAI Commuterline brand color.
  static const Color _fallbackLineColor = Color(0xFF9CA3AF);

  // Central Jakarta — a sensible default center before real station data
  // has loaded.
  static const LatLng _defaultCenter = LatLng(-6.2088, 106.8456);

  @override
  Widget build(BuildContext context) {
    final stations = ref.watch(stationListProvider);
    final youAreHere = ref.watch(liveTripPositionControllerProvider);
    final lineColors =
        ref.watch(lineColorsProvider).asData?.value ?? const <String, Color>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Peta perjalanan')),
      body: SafeArea(
        child: stations.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const AppEmptyState(
            icon: Icons.map_outlined,
            title: 'Peta belum tersedia',
            message: 'Data jalur tidak dapat dimuat.',
          ),
          data: (items) {
            if (items.isEmpty) {
              return const AppEmptyState(
                icon: Icons.map_outlined,
                title: 'Peta belum tersedia',
                message: 'Belum ada data stasiun.',
              );
            }
            return _buildMap(items, youAreHere, lineColors);
          },
        ),
      ),
    );
  }

  Widget _buildMap(
    List<Station> stations,
    LatLng? youAreHere,
    Map<String, Color> lineColors,
  ) {
    final allLineIds = stations.expand((s) => s.lineIds).toSet().toList()
      ..sort();

    final polylines = <Polyline<Object>>[
      for (var i = 0; i < allLineIds.length; i += 1)
        if (_lineTrackPoints(stations, allLineIds[i]) case final points
            when points.length >= 2)
          Polyline<Object>(
            points: points,
            color: lineColors[allLineIds[i]] ?? _fallbackLineColor,
            strokeWidth: 4,
          ),
    ];

    final center = stations.isNotEmpty
        ? LatLng(stations.first.latitude, stations.first.longitude)
        : _defaultCenter;

    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 11,
            minZoom: 9,
            maxZoom: 18,
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'id.temankereta.teman_kereta',
            ),
            PolylineLayer<Object>(polylines: polylines),
            MarkerLayer(
              markers: <Marker>[
                for (final station in stations)
                  Marker(
                    point: LatLng(station.latitude, station.longitude),
                    width: 110,
                    height: 14,
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => _showStationName(station),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.navy,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              station.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: Colors.white,
                                    offset: Offset(0.5, 0.5),
                                    blurRadius: 1,
                                  ),
                                  Shadow(
                                    color: Colors.white,
                                    offset: Offset(-0.5, -0.5),
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (youAreHere != null)
                  Marker(
                    point: youAreHere,
                    width: 22,
                    height: 22,
                    child: const _YouAreHereMarker(),
                  ),
                if (_myLocation != null)
                  Marker(
                    point: _myLocation!,
                    width: 20,
                    height: 20,
                    child: const _MyLocationMarker(),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 12,
          top: 12,
          child: _MapControls(
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
            onLocateMe: _goToMyLocation,
            locating: _locatingMe,
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _LineLegend(
            lineIds: allLineIds,
            labels: _lineLabels,
            colors: lineColors,
            fallbackColor: _fallbackLineColor,
          ),
        ),
      ],
    );
  }

  /// Older/mock data uses long-form line codes that don't match the real
  /// production `lines.code` values in [railLineShapes] — map them so both
  /// naming schemes resolve to the same real track geometry.
  static const Map<String, String> _lineIdAliases = <String, String>{
    'RANGKASBITUNG': 'RANGKAS',
    'TANJUNG_PRIOK': 'PRIOK',
  };

  /// The polyline to draw for [lineId]: the real track geometry from
  /// [railLineShapes] (sourced from OpenStreetMap route relations) when
  /// available, otherwise a straight-segment fallback through
  /// [_orderedLineStations] for lines OSM data hasn't been fetched for yet.
  List<LatLng> _lineTrackPoints(List<Station> stations, String lineId) {
    final shape = railLineShapes[lineId] ?? railLineShapes[_lineIdAliases[lineId]];
    if (shape != null) {
      return shape
          .map((point) => LatLng(point[0], point[1]))
          .toList(growable: false);
    }
    return _orderedLineStations(stations, lineId)
        .map((s) => LatLng(s.latitude, s.longitude))
        .toList(growable: false);
  }

  /// Real stations on [lineId], ordered by `Station.stopOrderByLine[lineId]`
  /// — used only as a fallback polyline (straight segments between
  /// consecutive stations) for lines not covered by [railLineShapes].
  List<Station> _orderedLineStations(List<Station> stations, String lineId) {
    final onLine = stations
        .where((s) => s.lineIds.contains(lineId))
        .toList(growable: false);
    onLine.sort((a, b) {
      final orderA = a.stopOrderByLine[lineId];
      final orderB = b.stopOrderByLine[lineId];
      if (orderA != null && orderB != null) {
        return orderA.compareTo(orderB);
      }
      // Stations missing stop-order data (non-Supabase providers) fall back
      // to latitude so the line still draws something reasonable rather
      // than nothing.
      return a.latitude.compareTo(b.latitude);
    });
    return onLine;
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      (camera.zoom + delta).clamp(9, 18),
    );
  }

  /// Centers the map on the device's current position, requesting location
  /// permission if needed — an explicit tap on a clearly-labeled "lokasi
  /// saya" button already explains why, matching the pattern in
  /// `NearestStationController.requestPermissionAndRefresh`.
  Future<void> _goToMyLocation() async {
    if (_locatingMe) {
      return;
    }
    setState(() => _locatingMe = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationMessage('Aktifkan layanan lokasi di perangkat Anda.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) {
        _showLocationMessage('Izin lokasi diperlukan untuk fitur ini.');
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
      setState(() => _myLocation = here);
      _mapController.move(here, 15);
    } on Object {
      _showLocationMessage('Tidak dapat mengambil lokasi saat ini.');
    } finally {
      if (mounted) {
        setState(() => _locatingMe = false);
      }
    }
  }

  void _showLocationMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _showStationName(Station station) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(station.name), duration: const Duration(seconds: 2)),
    );
  }
}

class _YouAreHereMarker extends StatelessWidget {
  const _YouAreHereMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.coral,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 4),
        ],
      ),
      child: const Icon(Icons.person_pin_circle, size: 14, color: Colors.white),
    );
  }
}

class _MyLocationMarker extends StatelessWidget {
  const _MyLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 3)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 4),
        ],
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocateMe,
    required this.locating,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocateMe;
  final bool locating;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _MapControlButton(
          icon: locating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          onPressed: locating ? null : onLocateMe,
          tooltip: 'Lokasi saya',
        ),
        const SizedBox(height: 8),
        Material(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Column(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Perbesar',
                onPressed: onZoomIn,
              ),
              const Divider(height: 1),
              IconButton(
                icon: const Icon(Icons.remove),
                tooltip: 'Perkecil',
                onPressed: onZoomOut,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(icon: icon, tooltip: tooltip, onPressed: onPressed),
    );
  }
}

class _LineLegend extends StatelessWidget {
  const _LineLegend({
    required this.lineIds,
    required this.labels,
    required this.colors,
    required this.fallbackColor,
  });

  final List<String> lineIds;
  final Map<String, String> labels;
  final Map<String, Color> colors;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    if (lineIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          children: <Widget>[
            for (final lineId in lineIds)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 12,
                    height: 4,
                    color: colors[lineId] ?? fallbackColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labels[lineId] ?? lineId,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
