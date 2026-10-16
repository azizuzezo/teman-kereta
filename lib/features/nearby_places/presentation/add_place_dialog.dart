import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/config/app_environment.dart';
import '../../../domain/entities/transit_models.dart';

/// Categories offered when adding a place. They line up with the groups the
/// Explore page shows (`place_categories.dart`), so a new place lands under
/// the right chip.
const List<String> addPlaceCategories = <String>[
  'Kuliner',
  'Belanja',
  'Ibadah',
  'Kesehatan',
  'ATM & Bank',
  'Transportasi',
  'Taman',
  'Wisata',
  'Fasilitas',
];

/// Lets a signed-in rider submit a place near [station]. Calls [onAdded] after
/// the row is saved so the caller can reload its list.
Future<void> showAddPlaceDialog(
  BuildContext context, {
  required Station station,
  required VoidCallback onAdded,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AddPlaceDialog(station: station, onAdded: onAdded),
  );
}

class _AddPlaceDialog extends StatefulWidget {
  const _AddPlaceDialog({required this.station, required this.onAdded});

  final Station station;
  final VoidCallback onAdded;

  @override
  State<_AddPlaceDialog> createState() => _AddPlaceDialogState();
}

class _AddPlaceDialogState extends State<_AddPlaceDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  late final TextEditingController _lat = TextEditingController(
    text: widget.station.latitude.toStringAsFixed(5),
  );
  late final TextEditingController _lng = TextEditingController(
    text: widget.station.longitude.toStringAsFixed(5),
  );
  String _category = addPlaceCategories.first;
  Uint8List? _photo;
  bool _locating = false;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) {
      return;
    }
    final bytes = await picked.readAsBytes();
    if (mounted) {
      setState(() => _photo = bytes);
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    String? error;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error = 'Aktifkan layanan lokasi di HP kamu.';
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        final granted =
            permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse;
        if (!granted) {
          error = 'Izin lokasi diperlukan untuk memakai lokasimu.';
        } else {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            ),
          );
          _lat.text = position.latitude.toStringAsFixed(5);
          _lng.text = position.longitude.toStringAsFixed(5);
        }
      }
    } on Object {
      error = 'Lokasi belum bisa dibaca. Coba lagi.';
    }
    if (!mounted) {
      return;
    }
    setState(() => _locating = false);
    if (error != null) {
      _toast(error);
    }
  }

  /// Parses a coordinate typed with either "." or "," as the decimal mark.
  /// An empty field uses [fallback]; unreadable text returns null.
  static double? _parseCoordinate(String raw, {required double fallback}) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) {
      return fallback;
    }
    return double.tryParse(text);
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('Isi nama tempatnya dulu.');
      return;
    }
    final userId = AppEnvironment.supabaseEnabled
        ? Supabase.instance.client.auth.currentUser?.id
        : null;
    if (userId == null) {
      _toast('Fitur ini butuh koneksi ke server komunitas.');
      return;
    }
    // Indonesian keyboards often type "-6,2". An unreadable or out-of-range
    // value must be reported, never silently replaced by the station's spot.
    final lat = _parseCoordinate(_lat.text, fallback: widget.station.latitude);
    final lng = _parseCoordinate(_lng.text, fallback: widget.station.longitude);
    if (lat == null || lat < -90 || lat > 90) {
      _toast('Lintang tidak valid. Isi angka antara -90 dan 90.');
      return;
    }
    if (lng == null || lng < -180 || lng > 180) {
      _toast('Bujur tidak valid. Isi angka antara -180 dan 180.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final client = Supabase.instance.client;
      String? photoUrl;
      final photo = _photo;
      if (photo != null) {
        final path = '$userId/${const Uuid().v4()}.jpg';
        await client.storage
            .from('nearby-place-images')
            .uploadBinary(
              path,
              photo,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        photoUrl = client.storage
            .from('nearby-place-images')
            .getPublicUrl(path);
      }
      await client.from('nearby_places').insert(<String, Object?>{
        'station_id': widget.station.id,
        'name': name,
        'category': _category,
        'description': _description.text.trim(),
        'image_url': ?photoUrl,
        'latitude': lat,
        'longitude': lng,
        'source': 'community',
        'submitted_by': userId,
      });
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tempat baru berhasil ditambahkan.')),
      );
      widget.onAdded();
    } on Object {
      if (mounted) {
        setState(() => _submitting = false);
        _toast('Tempat belum tersimpan. Coba lagi.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelLarge;
    return AlertDialog(
      title: const Text('Tambah tempat sekitar'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Dekat Stasiun ${widget.station.name}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama tempat',
                hintText: 'Contoh: Warung Soto Pak Haji',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: <DropdownMenuItem<String>>[
                for (final c in addPlaceCategories)
                  DropdownMenuItem<String>(value: c, child: Text(c)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _category = value);
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Keterangan singkat',
                hintText: 'Jam buka, menu andalan, atau ciri tempatnya',
              ),
            ),
            const SizedBox(height: 14),
            Text('Foto (boleh dikosongkan)', style: labelStyle),
            const SizedBox(height: 6),
            if (_photo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    _photo!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(_photo == null ? 'Pilih foto' : 'Ganti foto'),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(child: Text('Lokasi tempat', style: labelStyle)),
                TextButton.icon(
                  onPressed: _locating ? null : _useMyLocation,
                  icon: _locating
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 16),
                  label: Text(
                    _locating ? 'Mencari lokasi...' : 'Pakai lokasi saya',
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _lat,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Lintang'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lng,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Bujur'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
