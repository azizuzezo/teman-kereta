import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/tk_components.dart';
import '../../../active_trip/presentation/active_trip_controller.dart';
import '../../data/intercity_repository.dart';
import '../../domain/intercity_models.dart';
import '../../domain/intercity_trip.dart';

/// "Mulai perjalanan" for an intercity ride: where from, where to, then which
/// train. Every train is its own entry, so the rider picks the one they are
/// actually on.
class IntercityTripCard extends ConsumerStatefulWidget {
  const IntercityTripCard({super.key});

  @override
  ConsumerState<IntercityTripCard> createState() => _IntercityTripCardState();
}

class _IntercityTripCardState extends ConsumerState<IntercityTripCard> {
  String? _originCode;
  String? _destinationCode;
  String? _serviceId;
  bool _starting = false;
  final TextEditingController _customName = TextEditingController();

  bool get _isCustom => _serviceId == customServiceId;

  @override
  void dispose() {
    _customName.dispose();
    super.dispose();
  }

  String _durationLabel(IntercityService service) {
    final from = service.stopAt(_originCode!)!;
    final to = service.stopAt(_destinationCode!)!;
    final minutes = (to.estimatedMinutes - from.estimatedMinutes).abs().round();
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return hours == 0 ? '≈ $rest menit' : '≈ $hours j ${rest.toString().padLeft(2, '0')} m';
  }

  Future<void> _pick(
    IntercityCatalog catalog, {
    required bool isOrigin,
  }) async {
    // Every station can be picked: a train that is missing from the list can
    // still be ridden by typing its name. Stations no listed train links to
    // the origin are marked so the rider knows.
    final reachable = isOrigin
        ? null
        : catalog.destinationsFrom(_originCode!).map((s) => s.code).toSet();
    final options = isOrigin
        ? catalog.allStations
        : catalog.allStations
              .where((s) => s.code != _originCode)
              .toList(growable: false);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _StationSheet(
        title: isOrigin ? 'Naik dari stasiun' : 'Turun di stasiun',
        stations: options,
        selectedCode: isOrigin ? _originCode : _destinationCode,
        reachableCodes: reachable,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isOrigin) {
        _originCode = picked;
        if (_destinationCode == picked) _destinationCode = null;
      } else {
        _destinationCode = picked;
      }
      _serviceId = null;
      _autoSelectSingleTrain(catalog);
    });
  }

  void _autoSelectSingleTrain(IntercityCatalog catalog) {
    if (_originCode == null || _destinationCode == null) return;
    final trains = catalog.servicesBetween(_originCode!, _destinationCode!);
    if (trains.length == 1) {
      _serviceId = trains.single.id;
    } else if (trains.isEmpty) {
      // Nothing listed for this pair: the only choice is a train of their own.
      _serviceId = customServiceId;
    }
  }

  void _swap(IntercityCatalog catalog) {
    if (_originCode == null || _destinationCode == null) return;
    setState(() {
      final o = _originCode;
      _originCode = _destinationCode;
      _destinationCode = o;
      _serviceId = null;
      _autoSelectSingleTrain(catalog);
    });
  }

  Future<void> _start(IntercityCatalog catalog) async {
    if (_serviceId == null || _originCode == null || _destinationCode == null) {
      return;
    }
    final typedName = _customName.text.trim();
    final service = _isCustom
        ? catalog.serviceForCustomRide(_originCode!, _destinationCode!)
        : catalog.serviceById(_serviceId!);
    if (service == null || (_isCustom && typedName.isEmpty)) return;
    final router = GoRouter.of(context);
    setState(() => _starting = true);
    final trip = buildIntercityTrip(
      service: service,
      catalog: catalog,
      boarding: _originCode!,
      destination: _destinationCode!,
      now: DateTime.now(),
      customName: _isCustom ? typedName : null,
    );
    await ref.read(activeTripControllerProvider.notifier).start(trip);
    if (mounted) setState(() => _starting = false);
    unawaited(router.push('/active-trip'));
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(intercityCatalogProvider);
    return catalogAsync.when(
      loading: () => const TkSkeleton(height: 200, radius: TkRadius.card),
      error: (error, stack) => TkCard(
        child: Text(
          'Data kereta antar kota belum bisa dibuka.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      data: _buildCard,
    );
  }

  Widget _buildCard(IntercityCatalog catalog) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final origin = _originCode == null ? null : catalog.stations[_originCode];
    final destination = _destinationCode == null
        ? null
        : catalog.stations[_destinationCode];
    final trains = origin != null && destination != null
        ? catalog.servicesBetween(origin.code, destination.code)
        : const <IntercityService>[];
    final ready =
        _serviceId != null &&
        !_starting &&
        (!_isCustom || _customName.text.trim().isNotEmpty);

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
                    _Field(
                      label: 'Naik dari',
                      icon: Icons.trip_origin_rounded,
                      value: origin?.name,
                      onTap: _starting ? null : () => _pick(catalog, isOrigin: true),
                    ),
                    const SizedBox(height: 8),
                    _Field(
                      label: 'Turun di',
                      icon: Icons.place_rounded,
                      value: destination?.name,
                      onTap: _starting || origin == null
                          ? null
                          : () => _pick(catalog, isOrigin: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                tooltip: 'Tukar stasiun naik dan turun',
                onPressed: _starting || origin == null || destination == null
                    ? null
                    : () => _swap(catalog),
                icon: const Icon(Icons.swap_vert_rounded),
              ),
            ],
          ),
          if (origin != null && destination != null) ...<Widget>[
            const SizedBox(height: 14),
            Text('Pilih kereta', style: textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final train in trains)
              _TrainTile(
                service: train,
                selected: _serviceId == train.id,
                duration: _durationLabel(train),
                note: _noteFor(train),
                onTap: _starting ? null : () => setState(() => _serviceId = train.id),
              ),
            _CustomTrainTile(
              selected: _isCustom,
              hasListedTrains: trains.isNotEmpty,
              controller: _customName,
              duration: _isCustom
                  ? _durationLabel(
                      catalog.serviceForCustomRide(origin.code, destination.code),
                    )
                  : null,
              onTap: _starting
                  ? null
                  : () => setState(() => _serviceId = customServiceId),
              onChanged: () => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: ready ? () => _start(catalog) : null,
              icon: _starting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.navigation_rounded, size: 18),
              label: const Text('Mulai perjalanan'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.notifications_active_outlined, size: 16, color: tk.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Kamu diingatkan 30, 15 dan 10 menit sebelum tiba. Jadwal '
                  'resmi tidak tersedia, jadi waktunya estimasi dari jarak rel '
                  'dan kecepatan kereta, lalu menyesuaikan saat berjalan.',
                  style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A heads-up when Wikipedia's note says the train does not stop here on
  /// every run, so the rider checks before relying on it.
  String? _noteFor(IntercityService service) {
    final notes = <String>[
      for (final code in <String?>[_originCode, _destinationCode])
        if (code != null && service.stopAt(code)?.qualifier != null)
          '${service.stopAt(code)!.qualifier}',
    ];
    if (!service.verified) notes.add('rute belum terverifikasi penuh');
    return notes.isEmpty ? null : 'Catatan: ${notes.join('; ')}';
  }
}

/// "Kereta lain": a train missing from the list, named by the rider.
class _CustomTrainTile extends StatelessWidget {
  const _CustomTrainTile({
    required this.selected,
    required this.hasListedTrains,
    required this.controller,
    required this.onTap,
    required this.onChanged,
    this.duration,
  });

  final bool selected;
  final bool hasListedTrains;
  final TextEditingController controller;
  final String? duration;
  final VoidCallback? onTap;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? tk.primarySoft : tk.surfaceAlt,
        borderRadius: BorderRadius.circular(TkRadius.control),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: selected ? tk.primary : tk.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            hasListedTrains
                                ? 'Kereta lain (isi nama sendiri)'
                                : 'Isi nama kereta sendiri',
                            style: textTheme.titleSmall,
                          ),
                          Text(
                            hasListedTrains
                                ? 'Kalau keretamu tidak ada di daftar.'
                                : 'Belum ada kereta tercatat untuk rute ini.',
                            style: textTheme.bodySmall?.copyWith(
                              color: tk.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (selected) ...<Widget>[
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Nama kereta, mis. Argo Parahyangan',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                  if (duration != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      'Estimasi $duration. Dihitung dari jarak, lalu '
                      'menyesuaikan kecepatan kereta saat berjalan.',
                      style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainTile extends StatelessWidget {
  const _TrainTile({
    required this.service,
    required this.selected,
    required this.duration,
    required this.onTap,
    this.note,
  });

  final IntercityService service;
  final bool selected;
  final String duration;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Kereta ${service.name}, $duration',
        excludeSemantics: true,
        child: Material(
          color: selected ? tk.primarySoft : tk.surfaceAlt,
          borderRadius: BorderRadius.circular(TkRadius.control),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: selected ? tk.primary : tk.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(service.name, style: textTheme.titleSmall),
                        Text(
                          '${service.classes.join(' • ')}  ·  $duration',
                          style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                        ),
                        if (note != null)
                          Text(
                            note!,
                            style: textTheme.bodySmall?.copyWith(color: tk.warning),
                          ),
                      ],
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$label, ${value ?? 'belum dipilih'}',
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
                          value ?? 'Pilih stasiun',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            color: value == null ? tk.textMuted : tk.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, size: 20, color: tk.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StationSheet extends StatefulWidget {
  const _StationSheet({
    required this.title,
    required this.stations,
    required this.selectedCode,
    this.reachableCodes,
  });

  final String title;
  final List<IntercityStation> stations;
  final String? selectedCode;

  /// Stations a listed train links to the origin; the others are marked.
  /// Null when there is nothing to compare with (choosing the origin).
  final Set<String>? reachableCodes;

  @override
  State<_StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<_StationSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = widget.stations
        .where(
          (s) =>
              query.isEmpty ||
              s.name.toLowerCase().contains(query) ||
              s.code.toLowerCase().contains(query),
        )
        .toList(growable: false);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
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
                    child: Text(
                      'Stasiun "$_query" tidak ditemukan.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final station = matches[index];
                      return ListTile(
                        leading: const Icon(Icons.train_outlined),
                        title: Text(station.name),
                        subtitle: Text(
                          widget.reachableCodes != null &&
                                  !widget.reachableCodes!.contains(station.code)
                              ? '${station.placeLabel} • belum ada kereta tercatat'
                              : station.placeLabel,
                        ),
                        selected: station.code == widget.selectedCode,
                        onTap: () => Navigator.pop(context, station.code),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
