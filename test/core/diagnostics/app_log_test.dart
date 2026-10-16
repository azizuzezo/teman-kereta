import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/diagnostics/app_log.dart';

class _MemorySink implements LogSink {
  final List<String> lines = <String>[];
  @override
  void write(String line) => lines.add(line);
  @override
  Future<void> flush() async {}
}

void main() {
  group('formatIso8601WithOffset', () {
    test('local times carry an explicit UTC offset', () {
      final out = formatIso8601WithOffset(DateTime(2026, 10, 15, 10, 22, 11, 34));
      expect(
        out,
        matches(RegExp(r'^2026-10-15T10:22:11\.034[+-]\d{2}:\d{2}$')),
      );
    });

    test('UTC times end in Z', () {
      expect(
        formatIso8601WithOffset(DateTime.utc(2026, 10, 15, 3, 22, 11)),
        endsWith('Z'),
      );
    });
  });

  group('LogBuffer', () {
    test('keeps only the newest `capacity` entries', () {
      final buffer = LogBuffer(capacity: 3);
      for (var i = 1; i <= 5; i++) {
        buffer.add(LogLevel.info, 'T', 'm$i');
      }
      expect(buffer.entries.map((e) => e.message), <String>['m3', 'm4', 'm5']);
      expect(buffer.tail(2).length, 2);
      expect(buffer.tail(2).last, endsWith('I [T] m5'));
    });

    test('redacts before storing and before the sink sees it', () {
      final sink = _MemorySink();
      final buffer = LogBuffer(sink: sink)
        ..add(LogLevel.warn, 'Auth', 'failed for a@b.com password=abc123');
      expect(buffer.entries.single.message, 'failed for [EMAIL] password=[REDACTED]');
      expect(sink.lines.single, isNot(contains('a@b.com')));
      expect(sink.lines.single, isNot(contains('abc123')));
    });

    test('truncates very long messages', () {
      final buffer = LogBuffer(maxMessageLength: 50)
        ..add(LogLevel.info, 'T', 'x' * 500);
      expect(buffer.entries.single.message.length, lessThan(80));
      expect(buffer.entries.single.message, endsWith('[dipotong]'));
    });

    test('remembers the last error entry only', () {
      final buffer = LogBuffer()
        ..add(LogLevel.error, 'A', 'first')
        ..add(LogLevel.info, 'A', 'ok')
        ..add(LogLevel.error, 'B', 'second');
      expect(buffer.lastError!.message, 'second');
      buffer.clear();
      expect(buffer.lastError, isNull);
    });

    test('a failing sink never throws into the caller', () {
      final buffer = LogBuffer(sink: _ThrowingSink());
      expect(() => buffer.add(LogLevel.info, 'T', 'x'), returnsNormally);
      expect(buffer.entries, hasLength(1));
    });
  });

  group('RotatingFileLogSink', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('tk_log_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('writes lines and reads them back in order', () async {
      final sink = RotatingFileLogSink(dir)
        ..write('line one')
        ..write('line two');
      await sink.flush();
      expect(await sink.readPersistedLines(), <String>['line one', 'line two']);
    });

    test('rotates to app_log.old.txt past the size cap and keeps history', () async {
      final sink = RotatingFileLogSink(dir, maxFileBytes: 100);
      for (var i = 0; i < 4; i++) {
        sink.write('${'a' * 60} #$i');
        await sink.flush();
      }
      expect(sink.previousFile.existsSync(), isTrue);
      expect(sink.currentFile.lengthSync(), lessThanOrEqualTo(200));
      final lines = await sink.readPersistedLines();
      expect(lines.last, endsWith('#3'));
      expect(lines.length, greaterThanOrEqualTo(2));
    });

    test('readPersistedLines caps the number of lines returned', () async {
      final sink = RotatingFileLogSink(dir);
      for (var i = 0; i < 10; i++) {
        sink.write('l$i');
      }
      await sink.flush();
      expect(await sink.readPersistedLines(maxLines: 3), <String>['l7', 'l8', 'l9']);
    });
  });
}

class _ThrowingSink implements LogSink {
  @override
  void write(String line) => throw StateError('disk full');
  @override
  Future<void> flush() async {}
}
