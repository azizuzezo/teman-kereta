import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/config/app_environment.dart';
import '../../../core/widgets/auth_guard.dart';
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
              error: (error, stack) =>
                  const Text('Pilihan stasiun belum tersedia.'),
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
                        message:
                            'Belum ada destinasi terdaftar untuk stasiun ini.',
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
        onPressed: () => checkAuthOrPrompt(
          context,
          featureName: 'menambah tempat',
          onAllowed: () => _showAddPlaceDialog(context),
        ),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Tambah Tempat'),
      ),
    );
  }

  void _showAddPlaceDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    // Default to selected station coordinates
    final station = ref
        .read(stationListProvider)
        .asData
        ?.value
        .firstWhere(
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
    Uint8List? photoBytes;
    var locatingGps = false;
    var submitting = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickPhoto() async {
            final picked = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 80,
              maxWidth: 1600,
            );
            if (picked == null) return;
            final bytes = await picked.readAsBytes();
            setDialogState(() => photoBytes = bytes);
          }

          Future<void> fetchGpsLocation() async {
            setDialogState(() => locatingGps = true);
            String? errorMessage;
            try {
              if (!await Geolocator.isLocationServiceEnabled()) {
                errorMessage = 'Aktifkan layanan lokasi di perangkat kamu.';
              } else {
                var permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                }
                final granted =
                    permission == LocationPermission.always ||
                    permission == LocationPermission.whileInUse;
                if (!granted) {
                  errorMessage = 'Izin lokasi diperlukan untuk fitur ini.';
                } else {
                  final position = await Geolocator.getCurrentPosition(
                    locationSettings: const LocationSettings(
                      accuracy: LocationAccuracy.high,
                      timeLimit: Duration(seconds: 8),
                    ),
                  );
                  latController.text = position.latitude.toStringAsFixed(5);
                  lngController.text = position.longitude.toStringAsFixed(5);
                }
              }
            } on Object {
              errorMessage = 'Lokasi tidak dapat dibaca. Coba lagi.';
            }
            setDialogState(() => locatingGps = false);
            if (errorMessage != null && context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(errorMessage)));
            }
          }

          Future<void> submit() async {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            final userId = Supabase.instance.client.auth.currentUser?.id;
            if (!AppEnvironment.supabaseEnabled || userId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur ini butuh koneksi ke server komunitas.'),
                ),
              );
              return;
            }
            setDialogState(() => submitting = true);
            try {
              String? photoUrl;
              if (photoBytes != null) {
                final path = '$userId/${const Uuid().v4()}.jpg';
                await Supabase.instance.client.storage
                    .from('nearby-place-images')
                    .uploadBinary(
                      path,
                      photoBytes!,
                      fileOptions: const FileOptions(contentType: 'image/jpeg'),
                    );
                photoUrl = Supabase.instance.client.storage
                    .from('nearby-place-images')
                    .getPublicUrl(path);
              }
              final lat = double.tryParse(latController.text.trim()) ?? 0.0;
              final lng = double.tryParse(lngController.text.trim()) ?? 0.0;
              await Supabase.instance.client.from('nearby_places').insert({
                'station_id': _stationId,
                'name': name,
                'category': category,
                'description': descriptionController.text.trim(),
                'image_url': ?photoUrl,
                'latitude': lat,
                'longitude': lng,
                'source': 'community',
                'submitted_by': userId,
              });
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tempat baru berhasil ditambahkan.'),
                ),
              );
              ref.invalidate(nearbyPlacesProvider(_stationId));
            } on Object {
              setDialogState(() => submitting = false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gagal menyimpan tempat. Coba lagi.'),
                  ),
                );
              }
            }
          }

          return AlertDialog(
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
                      DropdownMenuItem(
                        value: 'Kuliner',
                        child: Text('Kuliner'),
                      ),
                      DropdownMenuItem(value: 'Wisata', child: Text('Wisata')),
                      DropdownMenuItem(value: 'Taman', child: Text('Taman')),
                      DropdownMenuItem(
                        value: 'Belanja',
                        child: Text('Belanja'),
                      ),
                      DropdownMenuItem(
                        value: 'Fasilitas',
                        child: Text('Fasilitas'),
                      ),
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
                  const Text(
                    'Foto Destinasi (opsional)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  if (photoBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        photoBytes!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: pickPhoto,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(
                      photoBytes == null ? 'Pilih Foto' : 'Ganti Foto',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text(
                        'Koordinat GPS',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: locatingGps ? null : fetchGpsLocation,
                        icon: locatingGps
                            ? const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, size: 16),
                        label: Text(
                          locatingGps
                              ? 'Mencari lokasi...'
                              : 'Pakai lokasi saya',
                        ),
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
                            prefixIcon: Icon(
                              Icons.location_on_outlined,
                              size: 18,
                            ),
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
                            prefixIcon: Icon(
                              Icons.location_on_outlined,
                              size: 18,
                            ),
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
                onPressed: submitting ? null : submit,
                child: submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan'),
              ),
            ],
          );
        },
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
        onTap: () => _showPlaceDetailsBottomSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (place.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    place.imageUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        CircleAvatar(child: Icon(_iconFor(place.category))),
                  ),
                )
              else
                CircleAvatar(child: Icon(_iconFor(place.category))),
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
                    Text(
                      '${place.category} • ${place.walkingMinutes} menit jalan',
                    ),
                    Text(
                      '${place.distanceMeters} meter',
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

  void _showPlaceDetailsBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (bottomSheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: <Widget>[
            if (place.imageUrl != null) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  place.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(place.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Chip(
                  label: Text(place.category),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Text(
                  '${place.distanceMeters} meter • ${place.walkingMinutes} menit jalan',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              place.description.isEmpty
                  ? 'Destinasi populer sekitar stasiun.'
                  : place.description,
            ),
            if (place.address != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                place.address!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              place.sourceLabel,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
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
