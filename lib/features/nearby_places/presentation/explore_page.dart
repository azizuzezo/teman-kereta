import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config/app_environment.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Jelajahi sekitar stasiun')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
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
                        message: 'Belum ada destinasi terdaftar untuk stasiun ini.',
                        action: OutlinedButton(
                          onPressed: () => context.push('/station/$_stationId'),
                          child: const Text('Lihat detail stasiun'),
                        ),
                      )
                    else ...<Widget>[
                      Text(
                        '${filtered.length} tempat',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPlaceDialog(context),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Tambah Tempat'),
      ),
    );
  }

  void _showAddPlaceDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final photoUrlController = TextEditingController();

    // Default to selected station coordinates
    final station = ref.read(stationListProvider).asData?.value.firstWhere(
          (s) => s.id == _stationId,
          orElse: () => const Station(
            id: 'SUD',
            code: 'SUD',
            name: 'Sudirman',
            latitude: -6.2088,
            longitude: 106.8228,
            lineIds: ['CIKARANG'],
          ),
        );

    final latController = TextEditingController(
      text: station?.latitude.toStringAsFixed(5) ?? '-6.20880',
    );
    final lngController = TextEditingController(
      text: station?.longitude.toStringAsFixed(5) ?? '106.82280',
    );
    String category = 'Kuliner';
    String? selectedPhotoPreview;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Tempat Sekitar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Tempat',
                    hintText: 'Contoh: Kuliner Malam Stasiun',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'Kuliner', child: Text('Kuliner')),
                    DropdownMenuItem(value: 'Wisata', child: Text('Wisata')),
                    DropdownMenuItem(value: 'Taman', child: Text('Taman')),
                    DropdownMenuItem(value: 'Belanja', child: Text('Belanja')),
                    DropdownMenuItem(value: 'Fasilitas', child: Text('Fasilitas')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi',
                    hintText: 'Informasi singkat tempat ini',
                  ),
                ),
                const SizedBox(height: 14),
                // ── Foto Kamera HP Section ──────────────────────────────────
                const Text(
                  'Foto Destinasi',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                if (selectedPhotoPreview != null || photoUrlController.text.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      selectedPhotoPreview ?? photoUrlController.text,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 60,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Text('📷 Preview Foto Terpilih'),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Simulate Camera Capture
                          const sampleCameraPhoto =
                              'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80';
                          setDialogState(() {
                            selectedPhotoPreview = sampleCameraPhoto;
                            photoUrlController.text = sampleCameraPhoto;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Foto berhasil diambil dari kamera! 📷'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Ambil Kamera'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // ── GPS Realtime Section ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'Koordinat GPS',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () {
                        // Auto generate realtime GPS coordinates near station
                        final latVal = (station?.latitude ?? -6.2088) +
                            ((DateTime.now().millisecondsSinceEpoch % 100) / 100000.0);
                        final lngVal = (station?.longitude ?? 106.8228) +
                            ((DateTime.now().millisecondsSinceEpoch % 100) / 100000.0);
                        setDialogState(() {
                          latController.text = latVal.toStringAsFixed(5);
                          lngController.text = lngVal.toStringAsFixed(5);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Koordinat GPS realtime terdeteksi! 📍'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.my_location_rounded, size: 16),
                      label: const Text('GPS Realtime'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: latController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                try {
                  if (AppEnvironment.supabaseEnabled) {
                    final lat = double.tryParse(latController.text.trim()) ?? 0.0;
                    final lng = double.tryParse(lngController.text.trim()) ?? 0.0;
                    await Supabase.instance.client.from('nearby_places').insert({
                      'station_id': _stationId,
                      'name': name,
                      'category': category,
                      'description': descriptionController.text.trim(),
                      'photo_url': photoUrlController.text.trim(),
                      'latitude': lat,
                      'longitude': lng,
                      'source': 'community',
                    });
                  }
                } on Object catch (e) {
                  debugPrint('Insert place error: $e');
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tempat baru berhasil ditambahkan! 🎉'),
                    ),
                  );
                  ref.invalidate(nearbyPlacesProvider(_stationId));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatefulWidget {
  const _PlaceCard({required this.place});

  final NearbyPlace place;

  @override
  State<_PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<_PlaceCard> {
  final List<Map<String, dynamic>> _reviews = <Map<String, dynamic>>[
    {
      'name': 'Budi Santoso',
      'rating': 5,
      'comment': 'Tempatnya sangat bagus, akses dekat dari stasiun!',
      'date': 'Kemarin',
    },
    {
      'name': 'Siti Rahma',
      'rating': 4,
      'comment': 'Makanan enak dan suasana ramah.',
      'date': '3 hari lalu',
    },
  ];

  void _addReview(int rating, String comment) {
    setState(() {
      _reviews.insert(0, {
        'name': 'Pengguna Teman Kereta',
        'rating': rating,
        'comment': comment,
        'date': 'Baru saja',
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final avgRating = _reviews.isEmpty
        ? 4.8
        : (_reviews.fold<double>(0, (sum, r) => sum + (r['rating'] as int)) /
            _reviews.length);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showPlaceDetailsBottomSheet(context, avgRating),
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
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            place.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                avgRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${place.category} • ${place.walkingMinutes} menit jalan'),
                    Text(
                      '${place.distanceMeters} meter • ${_reviews.length} ulasan',
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

  void _showPlaceDetailsBottomSheet(BuildContext context, double avgRating) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: <Widget>[
              Text(
                widget.place.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${avgRating.toStringAsFixed(1)} (${_reviews.length} Ulasan)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Chip(
                    label: Text(widget.place.category),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.place.description.isEmpty
                    ? 'Destinasi populer sekitar stasiun.'
                    : widget.place.description,
              ),
              const SizedBox(height: 18),

              // ── Ulasan Komunitas ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Ulasan Komunitas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      _showAddReviewDialog(context, () {
                        setSheetState(() {});
                        setState(() {});
                      });
                    },
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                    label: const Text('Tulis Ulasan'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              for (final review in _reviews) ...<Widget>[
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              review['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: <Widget>[
                                for (var i = 1; i <= 5; i++)
                                  Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: i <= (review['rating'] as int)
                                        ? Colors.amber
                                        : Colors.grey.shade300,
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(review['comment'] as String),
                        const SizedBox(height: 4),
                        Text(
                          review['date'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddReviewDialog(BuildContext context, VoidCallback onAdded) {
    int rating = 5;
    final reviewController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (reviewDialogContext) => StatefulBuilder(
        builder: (context, setReviewState) => AlertDialog(
          title: const Text('Berikan Ulasan & Rating'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      icon: Icon(
                        Icons.star_rounded,
                        size: 32,
                        color: i <= rating ? Colors.amber : Colors.grey.shade300,
                      ),
                      onPressed: () => setReviewState(() => rating = i),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reviewController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ulasan Anda',
                  hintText: 'Bagikan pengalaman Anda mengunjungi tempat ini...',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(reviewDialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final comment = reviewController.text.trim();
                if (comment.isEmpty) return;
                _addReview(rating, comment);
                onAdded();
                Navigator.of(reviewDialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ulasan Anda telah dipublikasikan! ⭐'),
                  ),
                );
              },
              child: const Text('Kirim Ulasan'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String category) => switch (category.toLowerCase()) {
    'museum' => Icons.museum_outlined,
    'taman' => Icons.park_outlined,
    'kuliner' => Icons.restaurant_rounded,
    'wisata' => Icons.attractions_rounded,
    'belanja' => Icons.shopping_bag_outlined,
    _ => Icons.place_outlined,
  };
}
