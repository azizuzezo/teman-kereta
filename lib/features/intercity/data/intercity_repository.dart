import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/intercity_models.dart';

const intercityAssetPath = 'assets/intercity/intercity_v1.json';

IntercityCatalog _parse(String raw) =>
    IntercityCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);

/// The intercity trains, stations and tracks, bundled with the app so a ride
/// works with no signal at all (long stretches of the line have none).
final intercityCatalogProvider = FutureProvider<IntercityCatalog>((ref) async {
  final raw = await rootBundle.loadString(intercityAssetPath);
  return compute(_parse, raw);
});
