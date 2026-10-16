import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// The one place that decides where base-map tiles come from.
///
/// Tiles are OpenStreetMap's standard raster tiles. Their usage policy
/// (operations.osmfoundation.org/policies/tiles) allows an app to use them if
/// it sends an identifying User-Agent, caches tiles, keeps to two parallel
/// connections and shows attribution; this file does all four. The policy
/// also says heavy use may be blocked, so if the app grows, change
/// [urlTemplate] to a keyed or self-hosted tile service. Nothing else in the
/// map depends on the provider.
abstract final class MapTileSource {
  static const urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgent = 'TemanKereta/1.0 (id.temankereta.teman_kereta)';
  static const attributionText = 'OpenStreetMap contributors';
  static const attributionUrl = 'https://www.openstreetmap.org/copyright';

  /// Approximate colour of the sea/land fill of the standard style, used only
  /// to compute line-colour contrast. Not painted anywhere.
  static const lightBackgroundReference = Color(0xFFF2EFE9);

  /// The same fill after [darkTileFilter] is applied.
  static const darkBackgroundReference = Color(0xFF141414);

  /// Invert + hue-rotate 180 degrees + 15% dimming: turns the light standard
  /// style into a dark one while keeping water blue and parks green.
  static const darkTileFilter = ColorFilter.matrix(<double>[
    0.488, -1.216, -0.122, 0, 217, //
    -0.362, -0.366, -0.122, 0, 217, //
    -0.362, -1.216, 0.728, 0, 217, //
    0, 0, 0, 1, 0, //
  ]);

  /// [darkTileFilter] with the colour pulled toward grey first (one composed
  /// matrix, so still a single filter pass per frame). OSM draws motorways and
  /// trunk roads in saturated red/orange, which is exactly the hue of the KRL
  /// lines; muting the base map lets the rail lines stand out.
  static final ColorFilter darkMutedTileFilter = ColorFilter.matrix(
    composeColorMatrices(_darkTileMatrix, saturationMatrix(0.35)),
  );

  static const List<double> _darkTileMatrix = <double>[
    0.488, -1.216, -0.122, 0, 217, //
    -0.362, -0.366, -0.122, 0, 217, //
    -0.362, -1.216, 0.728, 0, 217, //
    0, 0, 0, 1, 0, //
  ];
}

/// Standard saturation matrix: 1 keeps colour, 0 is greyscale.
@visibleForTesting
List<double> saturationMatrix(double s) {
  const r = 0.2126;
  const g = 0.7152;
  const b = 0.0722;
  final i = 1 - s;
  return <double>[
    r * i + s, g * i, b * i, 0, 0, //
    r * i, g * i + s, b * i, 0, 0, //
    r * i, g * i, b * i + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// Matrix for "apply [first], then [second]" (both 4x5 Flutter colour
/// matrices). [first] must have no translation column, which holds for the
/// saturation matrix; [second]'s translation is carried over unchanged.
@visibleForTesting
List<double> composeColorMatrices(List<double> second, List<double> first) {
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row += 1) {
    for (var col = 0; col < 4; col += 1) {
      var sum = 0.0;
      for (var k = 0; k < 4; k += 1) {
        sum += second[row * 5 + k] * first[k * 5 + col];
      }
      out[row * 5 + col] = sum;
    }
    out[row * 5 + 4] = second[row * 5 + 4];
  }
  return out;
}

/// Decides when a cached tile may be served without asking the network.
@visibleForTesting
String tileCacheFileName(String url) {
  final uri = Uri.parse(url);
  final raw = '${uri.host}${uri.path}';
  return raw.replaceAll(RegExp(r'[^A-Za-z0-9.]+'), '_');
}

/// Whether a cached file of [age] counts as fresh ([freshFor]) or at least
/// usable when offline ([staleOk]).
@visibleForTesting
enum TileFreshness { fresh, stale, expired }

@visibleForTesting
TileFreshness tileFreshnessFor(
  Duration age, {
  Duration freshFor = const Duration(days: 7),
  Duration staleOk = const Duration(days: 30),
}) {
  if (age <= freshFor) {
    return TileFreshness.fresh;
  }
  if (age <= staleOk) {
    return TileFreshness.stale;
  }
  return TileFreshness.expired;
}

/// Disk cache plus a small download queue for map tiles.
///
/// flutter_map 7 only has Flutter's in-memory image cache, so every cold start
/// and every long pan re-downloaded tiles; OSM's policy asks clients not to do
/// that. Tiles live in the OS cache directory, so Android may reclaim them.
class TileRepository {
  TileRepository({
    Future<Directory> Function()? directory,
    Dio? dio,
    this.maxParallel = 2,
    this.maxBytes = 100 * 1024 * 1024,
  }) : _directory = directory ?? _defaultDirectory,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 12),
               responseType: ResponseType.bytes,
             ),
           );

  final Future<Directory> Function() _directory;
  final Dio _dio;
  final int maxParallel;
  final int maxBytes;

  Directory? _resolved;
  bool _pruned = false;
  int _running = 0;
  final List<Completer<void>> _waiting = <Completer<void>>[];
  final Map<String, Future<Uint8List>> _inFlight =
      <String, Future<Uint8List>>{};

  static Future<Directory> _defaultDirectory() async {
    final base = await getTemporaryDirectory();
    return Directory('${base.path}${Platform.pathSeparator}map_tiles');
  }

  Future<Uint8List> load(String url, Map<String, String> headers) async {
    final existing = _inFlight[url];
    if (existing != null) {
      return existing;
    }
    final future = _load(url, headers);
    _inFlight[url] = future;
    try {
      return await future;
    } finally {
      unawaited(_inFlight.remove(url));
    }
  }

  Future<Uint8List> _load(String url, Map<String, String> headers) async {
    File? file;
    Uint8List? staleBytes;
    try {
      final dir = _resolved ??= await _directory();
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      if (!_pruned) {
        _pruned = true;
        unawaited(_prune(dir));
      }
      file = File(
        '${dir.path}${Platform.pathSeparator}${tileCacheFileName(url)}',
      );
      if (file.existsSync()) {
        final age = DateTime.now().difference(file.lastModifiedSync());
        switch (tileFreshnessFor(age)) {
          case TileFreshness.fresh:
            return await file.readAsBytes();
          case TileFreshness.stale:
            staleBytes = await file.readAsBytes();
          case TileFreshness.expired:
            break;
        }
      }
    } on Object {
      // A broken cache must never break the map; fall through to the network.
    }

    try {
      final bytes = await _download(url, headers);
      if (file != null) {
        try {
          await file.writeAsBytes(bytes, flush: false);
        } on Object {
          // Cache write is best effort.
        }
      }
      return bytes;
    } on Object {
      if (staleBytes != null) {
        return staleBytes;
      }
      rethrow;
    }
  }

  Future<Uint8List> _download(String url, Map<String, String> headers) async {
    await _acquire();
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
          validateStatus: (status) => status == 200,
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw StateError('Tile kosong: $url');
      }
      return Uint8List.fromList(data);
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_running < maxParallel) {
      _running += 1;
      return;
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    await waiter.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      // Newest request first: after a pan, the tiles still on screen are the
      // ones asked for last.
      _waiting.removeLast().complete();
    } else {
      _running -= 1;
    }
  }

  Future<void> _prune(Directory dir) async {
    try {
      final files = <(File, FileStat)>[];
      var total = 0;
      for (final entity in dir.listSync()) {
        if (entity is File) {
          final stat = entity.statSync();
          files.add((entity, stat));
          total += stat.size;
        }
      }
      final now = DateTime.now();
      files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      for (final (file, stat) in files) {
        final expired =
            tileFreshnessFor(now.difference(stat.modified)) ==
            TileFreshness.expired;
        if (expired || total > maxBytes) {
          total -= stat.size;
          try {
            file.deleteSync();
          } on Object {
            // ignore
          }
        }
      }
    } on Object {
      // ignore
    }
  }

  void dispose() => _dio.close();
}

@immutable
class CachedTileImageProvider extends ImageProvider<CachedTileImageProvider> {
  const CachedTileImageProvider({
    required this.url,
    required this.repository,
    required this.headers,
  });

  final String url;
  final TileRepository repository;
  final Map<String, String> headers;

  @override
  Future<CachedTileImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<CachedTileImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _decode(key, decode),
      scale: 1,
      debugLabel: key.url,
    );
  }

  Future<ui.Codec> _decode(
    CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await repository.load(key.url, key.headers);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is CachedTileImageProvider && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

class CachedTileProvider extends TileProvider {
  CachedTileProvider(this.repository, {super.headers});

  final TileRepository repository;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedTileImageProvider(
      url: getTileUrl(coordinates, options),
      repository: repository,
      headers: headers,
    );
  }
}

/// Overridable in tests (a fake provider that never touches disk or network).
final mapTileProviderProvider = Provider<TileProvider>((ref) {
  final repository = TileRepository();
  ref.onDispose(repository.dispose);
  return CachedTileProvider(
    repository,
    headers: <String, String>{'User-Agent': MapTileSource.userAgent},
  );
});

/// Notices when tiles keep failing (offline, blocked), so the page can say so
/// instead of leaving a blank grey map. Degraded means [threshold] errors
/// within [window]; it clears by itself after a quiet [window].
class TileHealthTracker extends ChangeNotifier {
  TileHealthTracker({
    this.threshold = 4,
    this.window = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int threshold;
  final Duration window;
  final DateTime Function() _now;
  final List<DateTime> _errors = <DateTime>[];
  Timer? _clearTimer;
  bool _degraded = false;

  bool get isDegraded => _degraded;

  void recordError() {
    final now = _now();
    _errors
      ..add(now)
      ..removeWhere((t) => now.difference(t) > window);
    _clearTimer?.cancel();
    _clearTimer = Timer(window, reset);
    if (!_degraded && _errors.length >= threshold) {
      _degraded = true;
      notifyListeners();
    }
  }

  void reset() {
    _errors.clear();
    _clearTimer?.cancel();
    _clearTimer = null;
    if (_degraded) {
      _degraded = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }
}
