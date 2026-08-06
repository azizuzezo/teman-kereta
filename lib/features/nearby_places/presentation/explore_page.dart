import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_environment.dart';
import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({this.initialStationId = 'SUD', super.key});

  final String initialStationId;

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  late String _stationId = widget.initialStationId;
  String? _category;

  @override
  Widget build(BuildContext context) {
    final stations = ref.watch(stationListProvider);
    final places = ref.watch(nearbyPlacesProvider(_stationId));
    final isDemo = AppEnvironment.provider == TransitProviderKind.mock;

    return Scaffold(
      appBar: AppBar(title: const Text('Jelajahi sekitar stasiun')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            if (isDemo) ...<Widget>[
              const DemoDataBanner(),
              const SizedBox(height: 16),
            ],
            stations.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => const Text(
                'Pilihan stasiun belum tersedia.',
              ),
              data: (items) {
                final validValue = items.any((item) => item.id == _stationId)
                    ? _stationId
                    : items.firstOrNull?.id;
                return DropdownButtonFormField<String>(
                  initialValue: validValue,
                  decoration: const InputDecoration(
                    labelText: 'Stasiun acuan',
                    prefixIcon: Icon(Icons.train_outlined),
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final station in items)
                      DropdownMenuItem(
                        value: station.id,
                        child: Text(station.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _stationId = value;
                        _category = null;
                      });
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 18),
            places.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => const AppEmptyState(
                icon: Icons.place_outlined,
                title: 'Tempat belum tersedia',
                message: 'Cache destinasi lokal tidak dapat dibaca.',
              ),
              data: (items) {
                final categories = items
                    .map((item) => item.category)
                    .toSet()
                    .toList(growable: false);
                final filtered = _category == null
                    ? items
                    : items
                          .where((item) => item.category == _category)
                          .toList(growable: false);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (categories.isNotEmpty) ...<Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilterChip(
                            label: const Text('Semua'),
                            selected: _category == null,
                            onSelected: (_) => setState(() => _category = null),
                          ),
                          for (final category in categories)
                            FilterChip(
                              label: Text(category),
                              selected: _category == category,
                              onSelected: (_) =>
                                  setState(() => _category = category),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (filtered.isEmpty)
                      AppEmptyState(
                        icon: Icons.travel_explore_outlined,
                        title: 'Belum ada tempat terdaftar',
                        message: isDemo
                            ? 'Data demo untuk stasiun ini belum diisi. Coba Bogor, Sudirman, atau Jakarta Kota.'
                            : 'Belum ada destinasi terdaftar untuk stasiun ini.',
                        action: OutlinedButton(
                          onPressed: () => context.push('/station/$_stationId'),
                          child: const Text('Lihat detail stasiun'),
                        ),
                      )
                    else ...<Widget>[
                      Text(
                        isDemo
                            ? '${filtered.length} tempat contoh'
                            : '${filtered.length} tempat',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      for (final place in filtered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PlaceCard(place: place),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place});

  final NearbyPlace place;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(place.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(place.description),
                  const SizedBox(height: 12),
                  Text(place.sourceLabel, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                child: Icon(_iconFor(place.category)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      place.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('${place.category} • ${place.walkingMinutes} menit jalan'),
                    Text(
                      place.isDemo
                          ? '${place.distanceMeters} meter • Data Demo'
                          : '${place.distanceMeters} meter',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String category) => switch (category.toLowerCase()) {
    'museum' => Icons.museum_outlined,
    'taman' => Icons.park_outlined,
    _ => Icons.place_outlined,
  };
}
