import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'log_redactor.dart';

enum LogLevel {
  debug('D'),
  info('I'),
  warn('W'),
  error('E');

  const LogLevel(this.letter);
  final String letter;
}

/// One log line. [format] renders `2026-10-15T10:22:11.034+07:00 E [tag] msg`.
@immutable
class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
  });

  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  String format() =>
      '${formatIso8601WithOffset(time)} ${level.letter} [$tag] $message';
}

/// ISO-8601 local time with an explicit UTC offset, e.g.
/// `2026-10-15T10:22:11.034+07:00`. Dart's own `toIso8601String` omits the
/// offset for local times, which makes logs ambiguous across time zones.
String formatIso8601WithOffset(DateTime time) {
  final local = time.isUtc ? time : time.toLocal();
  final base = local.toIso8601String();
  if (local.isUtc) {
    return base;
  }
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final hh = abs.inHours.toString().padLeft(2, '0');
  final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
  // toIso8601String has microsecond digits only when non-zero; trim to ms.
  final dot = base.indexOf('.');
  final trimmed = dot == -1 ? base : base.substring(0, dot + 4);
  return '$trimmed$sign$hh:$mm';
}

/// Receives formatted lines for persistence. Separated so the buffer is
/// testable without a filesystem.
abstract interface class LogSink {
  void write(String line);
  Future<void> flush();
}

/// In-memory ring buffer of the last [capacity] entries. Every message is
/// run through [redactSecrets] and capped at [maxMessageLength] on the way in.
class LogBuffer {
  LogBuffer({
    this.capacity = 400,
    this.maxMessageLength = 2000,
    DateTime Function()? clock,
    this.sink,
  }) : _clock = clock ?? DateTime.now;

  final int capacity;
  final int maxMessageLength;
  final LogSink? sink;
  final DateTime Function() _clock;
  final Queue<LogEntry> _entries = Queue<LogEntry>();

  /// Lines restored from the previous app session (read from the log file at
  /// install time). Kept apart from [entries] so reports can label them.
  List<String> restoredLines = const <String>[];

  LogEntry? _lastError;

  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_entries);

  /// The most recent error-level entry of this session, or null.
  LogEntry? get lastError => _lastError;

  void add(LogLevel level, String tag, String message) {
    var text = redactSecrets(message);
    if (text.length > maxMessageLength) {
      text = '${text.substring(0, maxMessageLength)}... [dipotong]';
    }
    final entry = LogEntry(
      time: _clock(),
      level: level,
      tag: tag,
      message: text,
    );
    _entries.addLast(entry);
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
    if (level == LogLevel.error) {
      _lastError = entry;
    }
    try {
      sink?.write(entry.format());
    } on Object {
      // Logging must never throw into the caller.
    }
  }

  /// Newest [count] lines of this session, oldest first.
  List<String> tail(int count) {
    final all = _entries.map((e) => e.format()).toList(growable: false);
    return all.length <= count ? all : all.sublist(all.length - count);
  }

  void clear() {
    _entries.clear();
    _lastError = null;
  }
}

/// Appends to `app_log.txt` in [directory]; when it passes [maxFileBytes] it is
/// moved to `app_log.old.txt` (replacing the previous one). Two files of
/// [maxFileBytes] each keep the total under about 2 x cap, so the default
/// 256 KB gives the ~512 KB budget.
class RotatingFileLogSink implements LogSink {
  RotatingFileLogSink(
    this.directory, {
    this.maxFileBytes = 256 * 1024,
    this.flushInterval = const Duration(seconds: 2),
  });

  final Directory directory;
  final int maxFileBytes;
  final Duration flushInterval;

  final StringBuffer _pending = StringBuffer();
  Timer? _timer;
  Future<void> _chain = Future<void>.value();
  int _currentSize = -1;

  File get currentFile => File(p.join(directory.path, 'app_log.txt'));
  File get previousFile => File(p.join(directory.path, 'app_log.old.txt'));

  /// Last [maxLines] lines persisted by earlier sessions, oldest first.
  Future<List<String>> readPersistedLines({int maxLines = 200}) async {
    final lines = <String>[];
    for (final file in <File>[previousFile, currentFile]) {
      try {
        if (await file.exists()) {
          lines.addAll(
            (await file.readAsString()).split('\n').where((l) => l.isNotEmpty),
          );
        }
      } on Object {
        // Unreadable log file: skip, a missing history is not an error.
      }
    }
    return lines.length <= maxLines
        ? lines
        : lines.sublist(lines.length - maxLines);
  }

  @override
  void write(String line) {
    _pending
      ..write(line)
      ..write('\n');
    _timer ??= Timer(flushInterval, () {
      _timer = null;
      unawaited(flush());
    });
  }

  @override
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) {
      return _chain;
    }
    final chunk = _pending.toString();
    _pending.clear();
    _chain = _chain.then((_) => _append(chunk)).catchError((Object _) {});
    return _chain;
  }

  Future<void> _append(String chunk) async {
    await directory.create(recursive: true);
    final file = currentFile;
    if (_currentSize < 0) {
      _currentSize = await file.exists() ? await file.length() : 0;
    }
    if (_currentSize >= maxFileBytes) {
      if (await previousFile.exists()) {
        await previousFile.delete();
      }
      if (await file.exists()) {
        await file.rename(previousFile.path);
      }
      _currentSize = 0;
    }
    await file.writeAsString(chunk, mode: FileMode.append, flush: true);
    _currentSize += chunk.length;
  }
}

/// Process-wide log facade: `AppLog.i('Tag', 'message')`.
///
/// [install] hooks `debugPrint`, `FlutterError.onError` and
/// `PlatformDispatcher.onError` while still calling whatever handler was
/// installed before (so Sentry, when enabled, keeps working).
abstract final class AppLog {
  static LogBuffer buffer = LogBuffer();
  static RotatingFileLogSink? _fileSink;
  static bool _installed = false;

  static void d(String tag, String message) =>
      buffer.add(LogLevel.debug, tag, message);
  static void i(String tag, String message) =>
      buffer.add(LogLevel.info, tag, message);
  static void w(String tag, String message) =>
      buffer.add(LogLevel.warn, tag, message);

  /// [error] and [stack], when given, are appended to the message.
  static void e(String tag, String message, {Object? error, StackTrace? stack}) {
    final buf = StringBuffer(message);
    if (error != null) {
      buf.write(' | $error');
    }
    if (stack != null) {
      buf.write('\n${_trimStack(stack)}');
    }
    buffer.add(LogLevel.error, tag, buf.toString());
  }

  static Future<void> flush() async => _fileSink?.flush();

  /// Idempotent. Never throws: a broken log setup must not block startup.
  static Future<void> install({Directory? directory}) async {
    if (_installed) {
      return;
    }
    _installed = true;

    try {
      final dir = directory ?? await getApplicationDocumentsDirectory();
      final sink = RotatingFileLogSink(Directory(p.join(dir.path, 'logs')));
      final restored = await sink.readPersistedLines();
      buffer = LogBuffer(sink: sink)..restoredLines = restored;
      _fileSink = sink;
    } on Object catch (error) {
      // Keep the memory-only buffer.
      buffer.add(LogLevel.warn, 'AppLog', 'Log file unavailable: $error');
    }

    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        buffer.add(LogLevel.debug, 'print', message);
      }
      previousDebugPrint(message, wrapWidth: wrapWidth);
    };

    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      e(
        'flutter',
        details.exceptionAsString(),
        stack: details.stack,
      );
      unawaited(flush());
      if (previousFlutterOnError != null) {
        previousFlutterOnError(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    final previousDispatcherOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      e('uncaught', error.toString(), stack: stack);
      unawaited(flush());
      return previousDispatcherOnError?.call(error, stack) ?? false;
    };

    i('AppLog', 'Sesi dimulai (${buffer.restoredLines.length} baris lama dimuat)');
  }

  static String _trimStack(StackTrace stack) {
    final lines = stack.toString().split('\n');
    return lines.take(12).join('\n');
  }
}
