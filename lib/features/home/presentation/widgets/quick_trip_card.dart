import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/map_launcher.dart';
import '../../../../core/widgets/tk_components.dart';
import '../../../../domain/entities/transit_models.dart';
import '../../../active_trip/presentation/active_trip_controller.dart';
import '../../../schedule/presentation/trip_search_controller.dart';

/// "Mulai perjalanan": both ends of the trip are chosen by the rider every
/// time, nothing is pre-filled. The rider's nearest station is offered only
/// as a one-tap suggestion for the origin.
class QuickTripCard extends ConsumerStatefulWidget {
  const QuickTripCard({
    required this.nearestStationId,
    required this.nearestStationName,
    required this.stations,
    super.key,
  });

  final String? nearestStationId;
  final String? nearestStationName;
  final List<Station> stations;

  @override
  ConsumerState<QuickTripCard> createState() => _QuickTripCardState();
}

class _QuickTripCardState extends ConsumerState<QuickTripCard> {
  String? _originId;
  String? _destinationId;
  bool _planning = false;

  bool get _isReady =>
      _originId != null &&
      _destinationId != null &&
      _originId != _destinationId;

  String _stationName(String id) =>
      widget.stations.where((s) => s.id == id).firstOrNull?.name ?? id;

  /// Runs the search for the two stations the rider picked and returns the
  /// top-ranked trip (the same one "Pilihan tercepat" would show), or null
  /// with a snackbar if nothing was found.
  Future<TransitTrip?> _search() async {
    final originId = _originId;
    final destinationId = _destinationId;
    if (originId == null ||
        destinationId == null ||
        originId == destinationId) {
      return null;
    }
    final searchController = ref.read(tripSearchControllerProvider.notifier);
    searchController
      ..setOrigin(originId)
      ..setDestination(destinationId);
    if (mounted) setState(() => _planning = true);
    await searchController.search();
    final results = ref.read(tripSearchControllerProvider).results;
    if (mounted) setState(() => _planning = false);
    if (results.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada jadwal ditemukan. Coba lagi nanti.'),
          ),
        );
      }
      return null;
    }
    return results.first;
  }

  /// Captures the [GoRouter] up front rather than navigating via `context`
  /// at the end: a rebuild between the search and the navigation (for
  /// example this card moving in Home's list) can recreate this State, which
  /// would silently drop a context-based navigation.
  Future<void> _viewDetail() async {
    final router = GoRouter.of(context);
    final trip = await _search();
    if (trip == null) return;
    unawaited(router.push('/trip/${trip.id}'));
  }

  /// Starts the top-ranked trip immediately. Starting the trip changes
  /// `activeTripControllerProvider`, which Home reacts to by swapping this
  /// card out, hence the same router capture as [_viewDetail].
  Future<void> _startNow() async {
    final router = GoRouter.of(context);
    final trip = await _search();
    if (trip == null) return;
    await ref.read(activeTripControllerProvider.notifier).start(trip);
    unawaited(router.push('/active-trip'));
  }

  Future<void> _pickStation({required bool isOrigin}) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _StationPickerSheet(
        title: isOrigin ? 'Pilih stasiun awal' : 'Pilih stasiun akhir',
        stations: widget.stations,
        selectedId: isOrigin ? _originId : _destinationId,
        excludedId: isOrigin ? _destinationId : _originId,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isOrigin) {
        _originId = selected;
      } else {
        _destinationId = selected;
      }
    });
  }

  void _swap() {
    setState(() {
      final previousOrigin = _originId;
      _originId = _destinationId;
      _destinationId = previousOrigin;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final nearestId = widget.nearestStationId;
    final nearestName = widget.nearestStationName;
    final canSuggestNearest =
        nearestId != null && nearestName != null && _originId != nearestId;
    final sameEnds = _originId != null && _originId == _destinationId;

    return TkCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    _StationField(
                      label: 'Stasiun awal',
                      icon: Icons.trip_origin_rounded,
                      stationName: _originId == null
                          ? null
                          : _stationName(_originId!),
                      onTap: _planning
                          ? null
                          : () => _pickStation(isOrigin: true),
                    ),
                    const SizedBox(height: 8),
                    _StationField(
                      label: 'Stasiun akhir',
                      icon: Icons.place_rounded,
                      stationName: _destinationId == null
                          ? null
                          : _stationName(_destinationId!),
                      onTap: _planning
                          ? null
                          : () => _pickStation(isOrigin: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                tooltip: 'Tukar stasiun awal dan akhir',
                onPressed:
                    _planning || (_originId == null && _destinationId == null)
                    ? null
                    : _swap,
                icon: const Icon(Icons.swap_vert_rounded),
              ),
            ],
          ),
          if (canSuggestNearest) ...<Widget>[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: Icon(
                  Icons.near_me_outlined,
                  size: 16,
                  color: tk.primary,
                ),
                label: Text(
                  'Mulai dari $nearestName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: _planning
                    ? null
                    : () => setState(() {
                        _originId = nearestId;
                        if (_destinationId == nearestId) {
                          _destinationId = null;
                        }
                      }),
              ),
            ),
          ],
          if (sameEnds) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Icon(Icons.error_outline_rounded, size: 16, color: tk.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Stasiun awal dan akhir tidak boleh sama.',
                    style: textTheme.bodySmall?.copyWith(color: tk.danger),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (_planning)
            const SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: null,
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isReady ? _startNow : null,
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Langsung mulai'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isReady ? _viewDetail : null,
                    icon: const Icon(Icons.route_outlined, size: 18),
                    label: const Text('Lihat rute'),
                  ),
                ),
              ],
            ),
          if (_originId != null) ...<Widget>[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () {
                final station = widget.stations
                    .where((s) => s.id == _originId)
                    .firstOrNull;
                if (station != null) {
                  unawaited(
                    launchMapDirections(
                      station.latitude,
                      station.longitude,
                      label: station.name,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.directions_rounded, size: 18),
              label: Text(
                'Arah ke ${_stationName(_originId!)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One end of the trip: a tappable field that reads "Pilih stasiun" until the
/// rider chooses. Identical in weight for origin and destination.
class _StationField extends StatelessWidget {
  const _StationField({
    required this.label,
    required this.icon,
    required this.stationName,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String? stationName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final isEmpty = stationName == null;
    return Semantics(
      button: true,
      label: '$label, ${stationName ?? 'belum dipilih'}',
      excludeSemantics: true,
      child: Material(
        color: tk.surfaceAlt,
        borderRadius: BorderRadius.circular(TkRadius.control),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 18, color: tk.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(label, style: textTheme.bodySmall),
                        Text(
                          stationName ?? 'Pilih stasiun',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            color: isEmpty ? tk.textMuted : tk.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: tk.textMuted,
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

/// Searchable station list: the full KRL network is far too long to scroll.
class _StationPickerSheet extends StatefulWidget {
  const _StationPickerSheet({
    required this.title,
    required this.stations,
    required this.selectedId,
    required this.excludedId,
  });

  final String title;
  final List<Station> stations;
  final String? selectedId;

  /// The station already chosen for the other end: shown but not selectable.
  final String? excludedId;

  @override
  State<_StationPickerSheet> createState() => _StationPickerSheetState();
}

class _StationPickerSheetState extends State<_StationPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = widget.stations
        .where((station) {
          if (query.isEmpty) return true;
          return station.name.toLowerCase().contains(query) ||
              station.id.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Cari nama stasiun',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Stasiun "$_query" tidak ditemukan.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final station = matches[index];
                      final isExcluded = station.id == widget.excludedId;
                      return ListTile(
                        leading: const Icon(Icons.train_outlined),
                        title: Text(station.name),
                        subtitle: isExcluded
                            ? const Text('Sudah dipakai di ujung lainnya')
                            : null,
                        selected: station.id == widget.selectedId,
                        enabled: !isExcluded,
                        onTap: () => Navigator.pop(context, station.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
