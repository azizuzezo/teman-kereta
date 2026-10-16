import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/ride_hailing_launcher.dart';
import '../../../core/widgets/auth_guard.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/nearest_station_finder.dart';
import '../../live_map/presentation/live_map_geometry.dart';
import '../../stations/presentation/nearest_station_controller.dart';
import 'add_place_dialog.dart';
import 'place_actions.dart';
import 'place_categories.dart';

/// "Apa yang ada di sekitar stasiun?": pick a station, then see what is within
/// walking distance, grouped the way people think about it (makan, ibadah,
/// belanja...). Everything shown comes from `nearby_places`; nothing is
/// filled in when the data is missing.
///
/// Route: `/explore?station=SUD`. Without the parameter the page opens on the
/// station looked at last, then falls back to Sudirman.
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({this.initialStationId, super.key});

  final String? initialStationId;

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  static const _fallbackStationId = 'SUD';
  static const _previewPerGroup = 3;

  String? _pickedId;
  String? _categoryKey;
  final Set<String> _expanded = <String>{};

  Station _resolve(List<Station> stations, List<String> recents) {
    final wanted = <String?>[
      _pickedId,
      widget.initialStationId,
      if (recents.isNotEmpty) recents.first,
      _fallbackStationId,
    ];
    for (final id in wanted) {
      if (id == null) {
        continue;
      }
      for (final s in stations) {
        if (s.id == id || s.code == id) {
          return s;
        }
      }
    }
    return stations.first;
  }

  void _pick(Station station) {
    setState(() {
      _pickedId = station.id;
      _categoryKey = null;
      _expanded.clear();
    });
    unawaited(ref.read(exploreRecentsProvider.notifier).add(station.id));
  }

  Future<void> _openPicker(
    List<Station> stations,
    Station current,
    List<StationDistance> nearest,
    List<String> recents,
  ) async {
    final picked = await showModalBottomSheet<Station>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.tk.surface,
      builder: (_) => _StationPickerSheet(
        stations: stations,
        currentId: current.id,
        nearest: nearest,
        recents: recents,
      ),
    );
    if (picked != null && mounted) {
      _pick(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stations = ref.watch(stationListProvider);
    final recentsAsync = ref.watch(exploreRecentsProvider);
    final nearest =
        ref.watch(nearestStationControllerProvider).asData?.value ??
        const <StationDistance>[];

    return Scaffold(
      body: SafeArea(
        child: stations.when(
          loading: () => const _PageSkeleton(),
          error: (error, stack) => TkErrorState(
            title: 'Stasiun belum bisa dimuat',
            message: 'Periksa koneksi, lalu coba lagi.',
            onRetry: () => ref.invalidate(stationListProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const AppEmptyState(
                icon: Icons.train_outlined,
                title: 'Belum ada data stasiun',
                message: 'Daftar stasiun belum tersedia di perangkat ini.',
              );
            }
            final waitingForRecents =
                recentsAsync.isLoading &&
                _pickedId == null &&
                widget.initialStationId == null;
            if (waitingForRecents) {
              return const _PageSkeleton();
            }
            final recents = recentsAsync.asData?.value ?? const <String>[];
            final station = _resolve(items, recents);
            return _buildContent(items, station, nearest, recents);
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    List<Station> stations,
    Station station,
    List<StationDistance> nearest,
    List<String> recents,
  ) {
    final places = ref.watch(nearbyPlacesProvider(station.id));
    final text = Theme.of(context).textTheme;
    final tk = context.tk;

    StationDistance? fromUser;
    for (final n in nearest) {
      if (n.station.id == station.id) {
        fromUser = n;
        break;
      }
    }

    final quick = <_QuickPick>[
      if (nearest.isNotEmpty && nearest.first.station.id != station.id)
        _QuickPick(nearest.first.station, Icons.near_me_rounded, 'Terdekat'),
      for (final id in recents)
        if (id != station.id &&
            !(nearest.isNotEmpty && nearest.first.station.id == id))
          for (final s in stations)
            if (s.id == id) _QuickPick(s, Icons.history_rounded, null),
    ].take(4).toList();

    void addPlace() => checkAuthOrPrompt(
      context,
      featureName: 'menambah tempat',
      onAllowed: () => showAddPlaceDialog(
        context,
        station: station,
        onAdded: () => ref.invalidate(nearbyPlacesProvider(station.id)),
      ),
    );

    return Stack(
      children: <Widget>[
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                'Apa yang ada di sekitar stasiun?',
                style: text.headlineSmall,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pilih stasiun, lalu lihat tempat yang bisa dicapai dengan jalan kaki.',
              style: text.bodyMedium?.copyWith(color: tk.textMuted),
            ),
            const SizedBox(height: 16),
            _StationPickerCard(
              station: station,
              fromUser: fromUser,
              onTap: () => _openPicker(stations, station, nearest, recents),
            ),
            if (quick.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  for (final q in quick)
                    _QuickPickChip(pick: q, onTap: () => _pick(q.station)),
                ],
              ),
            ],
            const SizedBox(height: 20),
            places.when(
              loading: () => const _PlacesSkeleton(),
              error: (error, stack) => TkErrorState(
                title: 'Daftar tempat belum bisa dimuat',
                message: 'Periksa koneksi, lalu coba lagi.',
                onRetry: () => ref.invalidate(nearbyPlacesProvider(station.id)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyPlaces(
                    stationName: station.name,
                    onAdd: addPlace,
                    onStationDetail: () =>
                        context.push('/station/${station.id}'),
                  );
                }
                return _buildResults(items, station);
              },
            ),
          ],
        ),
        // The empty state carries its own "Tambah tempat" button, so the FAB
        // only appears once there are places to add to.
        if (places.value?.isNotEmpty ?? false)
          Positioned(
            right: 16,
            bottom: 16,
            // Icon only so the button stays small; the tooltip doubles as the
            // accessible label for screen readers.
            child: FloatingActionButton.small(
              onPressed: addPlace,
              tooltip: 'Tambah tempat',
              child: const Icon(Icons.add_location_alt_outlined),
            ),
          ),
      ],
    );
  }

  Widget _buildResults(List<NearbyPlace> items, Station station) {
    final groups = groupPlaces(items);
    final selectedKey = groups.any((g) => g.category.key == _categoryKey)
        ? _categoryKey
        : null;
    final tk = context.tk;
    final text = Theme.of(context).textTheme;

    final chips = <Widget>[
      _CategoryChip(
        icon: Icons.apps_rounded,
        label: 'Semua',
        count: items.length,
        selected: selectedKey == null,
        onTap: () => setState(() => _categoryKey = null),
      ),
      for (final g in groups)
        _CategoryChip(
          icon: g.category.icon,
          label: g.category.label,
          count: g.count,
          selected: selectedKey == g.category.key,
          onTap: () => setState(() => _categoryKey = g.category.key),
        ),
    ];

    final body = <Widget>[];
    if (selectedKey != null) {
      final group = groups.firstWhere((g) => g.category.key == selectedKey);
      for (final place in group.places) {
        body.add(_PlaceCard(place: place, station: station));
      }
    } else {
      for (final group in groups) {
        final open = _expanded.contains(group.category.key);
        final shown = open
            ? group.places
            : group.places.take(_previewPerGroup).toList();
        body.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Row(
              children: <Widget>[
                Icon(group.category.icon, color: tk.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.category.label,
                    style: text.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  placeCountLabel(group.count),
                  style: text.bodySmall?.copyWith(color: tk.textMuted),
                ),
              ],
            ),
          ),
        );
        for (final place in shown) {
          body.add(_PlaceCard(place: place, station: station));
        }
        if (group.count > _previewPerGroup) {
          body.add(
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  if (open) {
                    _expanded.remove(group.category.key);
                  } else {
                    _expanded.add(group.category.key);
                  }
                }),
                child: Text(
                  open
                      ? 'Tampilkan lebih sedikit'
                      : 'Lihat semua ${group.count} tempat',
                ),
              ),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TkSectionLabel('Pilih jenis tempat'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            final width = (constraints.maxWidth - gap * 2) / 3;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final chip in chips) SizedBox(width: width, child: chip),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        TkSectionLabel('Dekat Stasiun ${station.name}'),
        const SizedBox(height: 4),
        ...body,
      ],
    );
  }
}

class _QuickPick {
  const _QuickPick(this.station, this.icon, this.tag);
  final Station station;
  final IconData icon;
  final String? tag;
}

class _QuickPickChip extends StatelessWidget {
  const _QuickPickChip({required this.pick, required this.onTap});

  final _QuickPick pick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final label = pick.tag == null
        ? pick.station.name
        : '${pick.tag}: ${pick.station.name}';
    return Semantics(
      button: true,
      label: 'Pilih stasiun $label',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          widthFactor: 1,
          child: Material(
            color: tk.surfaceAlt,
            borderRadius: BorderRadius.circular(TkRadius.control),
            child: InkWell(
              borderRadius: BorderRadius.circular(TkRadius.control),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(pick.icon, size: 18, color: tk.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
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

class _StationPickerCard extends StatelessWidget {
  const _StationPickerCard({
    required this.station,
    required this.fromUser,
    required this.onTap,
  });

  final Station station;
  final StationDistance? fromUser;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final text = Theme.of(context).textTheme;
    final distance = fromUser;
    final lines = <String>{
      for (final id in station.lineIds) lineShortName(id),
    }.toList();
    final detail = <String>[
      if (lines.isNotEmpty) lines.join(', '),
      if (distance != null)
        '${formatDistanceMeters(distance.distanceMeters)} dari kamu',
    ].join(' • ');
    return TkCard(
      tone: TkCardTone.soft,
      onTap: onTap,
      semanticLabel: 'Stasiun ${station.name}. Ketuk untuk ganti stasiun.',
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: <Widget>[
          Icon(Icons.train_rounded, color: tk.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Stasiun',
                  style: text.labelMedium?.copyWith(color: tk.textMuted),
                ),
                Text(
                  station.name,
                  style: text.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: text.bodySmall?.copyWith(color: tk.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: const Text('Ganti')),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final text = Theme.of(context).textTheme;
    final fg = selected ? tk.onPrimary : tk.text;
    final muted = selected ? tk.onPrimary : tk.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, ${placeCountLabel(count)}',
      excludeSemantics: true,
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
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, color: fg, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(color: fg),
                  ),
                  Text(
                    placeCountLabel(count),
                    style: text.bodySmall?.copyWith(color: muted),
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

class _PlaceThumb extends StatelessWidget {
  const _PlaceThumb({required this.place});

  final NearbyPlace place;
  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final icon = categoryOf(place.category).icon;
    Widget tile() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tk.primarySoft,
        borderRadius: BorderRadius.circular(TkRadius.control),
      ),
      child: Icon(icon, color: tk.primary),
    );
    final url = place.imageUrl;
    if (url == null || url.isEmpty) {
      return tile();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(TkRadius.control),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => TkSkeleton(height: size, width: size),
        errorWidget: (_, _, _) => tile(),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.station});

  final NearbyPlace place;
  final Station station;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final text = Theme.of(context).textTheme;
    final summary = walkingSummary(place);
    final category = categoryOf(place.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TkCard(
        onTap: () => _showPlaceSheet(context, place, station),
        padding: const EdgeInsets.all(12),
        semanticLabel:
            '${place.name}, ${category.label}'
            '${summary == null ? '' : ', $summary'}. Ketuk untuk detail.',
        child: Row(
          children: <Widget>[
            _PlaceThumb(place: place),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    place.name,
                    style: text.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    category.label,
                    style: text.bodySmall?.copyWith(color: tk.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (summary != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.directions_walk_rounded,
                          size: 16,
                          color: tk.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            summary,
                            style: text.bodySmall?.copyWith(
                              color: tk.text,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: tk.textMuted),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlaces extends StatelessWidget {
  const _EmptyPlaces({
    required this.stationName,
    required this.onAdd,
    required this.onStationDetail,
  });

  final String stationName;
  final VoidCallback onAdd;
  final VoidCallback onStationDetail;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.travel_explore_outlined,
      title: 'Belum ada data tempat di sekitar stasiun ini',
      message:
          'Daftar tempat untuk Stasiun $stationName belum ada. Kalau kamu tahu tempat yang layak dikunjungi, tambahkan.',
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FilledButton(onPressed: onAdd, child: const Text('Tambah tempat')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onStationDetail,
            child: const Text('Lihat detail stasiun'),
          ),
        ],
      ),
    );
  }
}

class _PlacesSkeleton extends StatelessWidget {
  const _PlacesSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: TkSkeleton(height: 88, radius: TkRadius.control)),
            SizedBox(width: 8),
            Expanded(child: TkSkeleton(height: 88, radius: TkRadius.control)),
            SizedBox(width: 8),
            Expanded(child: TkSkeleton(height: 88, radius: TkRadius.control)),
          ],
        ),
        SizedBox(height: 20),
        TkListSkeleton(count: 4),
      ],
    );
  }
}

class _PageSkeleton extends StatelessWidget {
  const _PageSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TkSkeleton(height: 28, width: 260),
          SizedBox(height: 8),
          TkSkeleton(height: 16),
          SizedBox(height: 16),
          TkSkeleton(height: 72, radius: TkRadius.card),
          SizedBox(height: 20),
          _PlacesSkeleton(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Station picker
// ---------------------------------------------------------------------------

class _StationPickerSheet extends StatefulWidget {
  const _StationPickerSheet({
    required this.stations,
    required this.currentId,
    required this.nearest,
    required this.recents,
  });

  final List<Station> stations;
  final String currentId;
  final List<StationDistance> nearest;
  final List<String> recents;

  @override
  State<_StationPickerSheet> createState() => _StationPickerSheetState();
}

class _StationPickerSheetState extends State<_StationPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final text = Theme.of(context).textTheme;
    final searching = _query.trim().isNotEmpty;

    final rows = <Widget>[];
    void header(String label) => rows.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Text(
          label,
          style: text.labelMedium?.copyWith(color: tk.textMuted),
        ),
      ),
    );
    Widget tile(Station s, {String? subtitle}) => ListTile(
      minTileHeight: 56,
      leading: Icon(
        s.id == widget.currentId
            ? Icons.check_circle_rounded
            : Icons.train_outlined,
        color: s.id == widget.currentId ? tk.primary : tk.textMuted,
      ),
      title: Text(s.name),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: () => Navigator.of(context).pop(s),
    );

    if (searching) {
      final results = searchStations(widget.stations, _query);
      if (results.isEmpty) {
        rows.add(
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Tidak ada stasiun bernama "${_query.trim()}".',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: tk.textMuted),
            ),
          ),
        );
      } else {
        for (final s in results) {
          rows.add(tile(s));
        }
      }
    } else {
      header('Terdekat dari kamu');
      if (widget.nearest.isEmpty) {
        rows.add(
          ListTile(
            minTileHeight: 56,
            leading: Icon(Icons.near_me_disabled_outlined, color: tk.textMuted),
            title: const Text('Aktifkan lokasi untuk melihat yang terdekat'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).pop();
              unawaited(context.push('/settings/location'));
            },
          ),
        );
      } else {
        for (final n in widget.nearest.take(3)) {
          rows.add(
            tile(
              n.station,
              subtitle:
                  '${formatDistanceMeters(n.distanceMeters)} • '
                  '${n.walkingMinutes} menit jalan',
            ),
          );
        }
      }
      final byId = {for (final s in widget.stations) s.id: s};
      final recent = <Station>[
        for (final id in widget.recents)
          if (byId[id] != null) byId[id]!,
      ];
      if (recent.isNotEmpty) {
        header('Terakhir dilihat');
        for (final s in recent) {
          rows.add(tile(s));
        }
      }
      header('Semua stasiun');
      for (final s in searchStations(
        widget.stations,
        '',
        limit: widget.stations.length,
      )) {
        rows.add(tile(s));
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: TextField(
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari nama stasiun',
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
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Place detail
// ---------------------------------------------------------------------------

void _showPlaceSheet(BuildContext context, NearbyPlace place, Station station) {
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.tk.surface,
      builder: (_) => _PlaceSheet(place: place, station: station),
    ),
  );
}

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({required this.place, required this.station});

  final NearbyPlace place;
  final Station station;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  bool _busy = false;
  String? _error;

  Future<PlaceTarget> _target() async {
    final coords = await fetchPlaceCoordinates(widget.place.id);
    return PlaceTarget(
      name: widget.place.name,
      stationName: widget.station.name,
      latitude: coords?.$1,
      longitude: coords?.$2,
    );
  }

  Future<void> _run(Future<bool> Function(PlaceTarget) action) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final target = await _target();
    final ok = await action(target);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = ok ? null : 'Aplikasi peta belum bisa dibuka di HP ini.';
    });
  }

  Future<void> _directions() => _run((t) {
    final uri = buildWalkingDirectionsUri(
      t,
      stationLatitude: widget.station.latitude,
      stationLongitude: widget.station.longitude,
    );
    return launchWithFallback(uri, uri);
  });

  Future<void> _openMap() => _run(
    (t) => launchWithFallback(buildOpenInMapUri(t), buildOpenInMapWebUri(t)),
  );

  Future<void> _rideHail(RideHailingApp app) async {
    try {
      await const RideHailingLauncher().open(app);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Aplikasi belum bisa dibuka di HP ini.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final text = Theme.of(context).textTheme;
    final place = widget.place;
    final category = categoryOf(place.category);
    final summary = walkingSummary(place);
    final url = place.imageUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (url != null && url.isNotEmpty) ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(TkRadius.control),
              child: CachedNetworkImage(
                imageUrl: url,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    const TkSkeleton(height: 160, radius: TkRadius.control),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(place.name, style: text.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              TkPill(label: category.label, icon: category.icon),
              if (summary != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.directions_walk_rounded,
                      size: 16,
                      color: tk.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$summary dari Stasiun ${widget.station.name}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
            ],
          ),
          if (place.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(place.description, style: text.bodyMedium),
          ],
          if (place.address != null && place.address!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              place.address!,
              style: text.bodySmall?.copyWith(color: tk.textMuted),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _directions,
                  icon: const Icon(Icons.directions_walk_rounded, size: 20),
                  label: const Text('Petunjuk jalan'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _openMap,
                  icon: const Icon(Icons.map_outlined, size: 20),
                  label: const Text('Buka di peta'),
                ),
              ),
            ],
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(_error!, style: text.bodySmall?.copyWith(color: tk.danger)),
          ],
          const SizedBox(height: 16),
          Text(
            'Terlalu jauh untuk jalan kaki?',
            style: text.labelMedium?.copyWith(color: tk.textMuted),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rideHail(RideHailingApp.gojek),
                  child: const Text('Buka Gojek'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rideHail(RideHailingApp.grab),
                  child: const Text('Buka Grab'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Aplikasinya dibuka, tujuan perlu kamu isi sendiri.',
            style: text.bodySmall?.copyWith(color: tk.textMuted),
          ),
          const SizedBox(height: 12),
          Text(
            'Sumber: ${place.sourceLabel}',
            style: text.bodySmall?.copyWith(color: tk.textMuted),
          ),
        ],
      ),
    );
  }
}
