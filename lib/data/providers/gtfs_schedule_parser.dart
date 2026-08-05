class GtfsStopRecord {
  const GtfsStopRecord({
    required this.stopId,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String stopId;
  final String name;
  final double latitude;
  final double longitude;
}

class GtfsRouteRecord {
  const GtfsRouteRecord({
    required this.routeId,
    this.shortName,
    this.longName,
    this.color,
  });

  final String routeId;
  final String? shortName;
  final String? longName;
  final String? color;
}

class GtfsTripRecord {
  const GtfsTripRecord({
    required this.tripId,
    required this.routeId,
    required this.serviceId,
    this.headsign,
    this.tripShortName,
  });

  final String tripId;
  final String routeId;
  final String serviceId;
  final String? headsign;
  final String? tripShortName;
}

/// Seconds since midnight of the trip's service day. GTFS allows values
/// >= 24:00:00 for a trip that runs past midnight without losing its
/// original service date — deliberately NOT wrapped modulo a day here.
class GtfsStopTimeRecord {
  const GtfsStopTimeRecord({
    required this.tripId,
    required this.stopId,
    required this.stopSequence,
    required this.arrivalSeconds,
    required this.departureSeconds,
  });

  final String tripId;
  final String stopId;
  final int stopSequence;
  final int arrivalSeconds;
  final int departureSeconds;
}

class GtfsCalendarRecord {
  const GtfsCalendarRecord({
    required this.serviceId,
    required this.weekdays,
    required this.startDate,
    required this.endDate,
  });

  final String serviceId;

  /// Index 0 = Monday .. 6 = Sunday, matching [DateTime.weekday] - 1.
  final List<bool> weekdays;
  final DateTime startDate;
  final DateTime endDate;
}

enum GtfsCalendarExceptionType { added, removed }

class GtfsCalendarDateRecord {
  const GtfsCalendarDateRecord({
    required this.serviceId,
    required this.date,
    required this.exceptionType,
  });

  final String serviceId;
  final DateTime date;
  final GtfsCalendarExceptionType exceptionType;
}

class GtfsScheduleParser {
  const GtfsScheduleParser();

  List<GtfsStopRecord> parseStops(String csvText) {
    return _mapRows(csvText, requiredColumns: const [
      'stop_id',
      'stop_name',
      'stop_lat',
      'stop_lon',
    ], build: (row, index) {
      final latitude = double.tryParse(row['stop_lat']!);
      final longitude = double.tryParse(row['stop_lon']!);
      if (latitude == null || longitude == null) {
        throw FormatException(
          'Koordinat GTFS tidak valid untuk ${row['stop_id']}.',
        );
      }
      return GtfsStopRecord(
        stopId: row['stop_id']!,
        name: row['stop_name']!,
        latitude: latitude,
        longitude: longitude,
      );
    });
  }

  List<GtfsRouteRecord> parseRoutes(String csvText) {
    return _mapRows(csvText, requiredColumns: const [
      'route_id',
    ], build: (row, index) {
      return GtfsRouteRecord(
        routeId: row['route_id']!,
        shortName: _nullIfEmpty(row['route_short_name']),
        longName: _nullIfEmpty(row['route_long_name']),
        color: _nullIfEmpty(row['route_color']),
      );
    });
  }

  List<GtfsTripRecord> parseTrips(String csvText) {
    return _mapRows(csvText, requiredColumns: const [
      'trip_id',
      'route_id',
      'service_id',
    ], build: (row, index) {
      return GtfsTripRecord(
        tripId: row['trip_id']!,
        routeId: row['route_id']!,
        serviceId: row['service_id']!,
        headsign: _nullIfEmpty(row['trip_headsign']),
        tripShortName: _nullIfEmpty(row['trip_short_name']),
      );
    });
  }

  List<GtfsStopTimeRecord> parseStopTimes(String csvText) {
    return _mapRows(csvText, requiredColumns: const [
      'trip_id',
      'stop_id',
      'stop_sequence',
      'arrival_time',
      'departure_time',
    ], build: (row, index) {
      final sequence = int.tryParse(row['stop_sequence']!);
      if (sequence == null) {
        throw FormatException(
          'stop_sequence tidak valid pada baris ${index + 1} stop_times.txt.',
        );
      }
      return GtfsStopTimeRecord(
        tripId: row['trip_id']!,
        stopId: row['stop_id']!,
        stopSequence: sequence,
        arrivalSeconds: _parseGtfsTimeOfDay(row['arrival_time']!),
        departureSeconds: _parseGtfsTimeOfDay(row['departure_time']!),
      );
    });
  }

  List<GtfsCalendarRecord> parseCalendar(String csvText) {
    return _mapRows(csvText, requiredColumns: const [
      'service_id',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
      'start_date',
      'end_date',
    ], build: (row, index) {
      return GtfsCalendarRecord(
        serviceId: row['service_id']!,
        weekdays: <bool>[
          row['monday'] == '1',
          row['tuesday'] == '1',
          row['wednesday'] == '1',
          row['thursday'] == '1',
          row['friday'] == '1',
          row['saturday'] == '1',
          row['sunday'] == '1',
        ],
        startDate: _parseGtfsDate(row['start_date']!),
        endDate: _parseGtfsDate(row['end_date']!),
      );
    });
  }

  List<GtfsCalendarDateRecord> parseCalendarDates(String csvText) {
    return _mapRows(csvText, requiredColumns: const [
      'service_id',
      'date',
      'exception_type',
    ], build: (row, index) {
      final exceptionType = row['exception_type'] == '1'
          ? GtfsCalendarExceptionType.added
          : GtfsCalendarExceptionType.removed;
      return GtfsCalendarDateRecord(
        serviceId: row['service_id']!,
        date: _parseGtfsDate(row['date']!),
        exceptionType: exceptionType,
      );
    });
  }

  String? _nullIfEmpty(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  /// GTFS `HH:MM:SS` — hours may exceed 23 for a service day that continues
  /// past midnight (e.g. `25:10:00`), so this returns raw seconds rather
  /// than wrapping to a 24h clock.
  int _parseGtfsTimeOfDay(String value) {
    final parts = value.split(':');
    if (parts.length != 3) {
      throw FormatException('Format waktu GTFS tidak valid: $value');
    }
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = int.tryParse(parts[2]);
    if (hours == null || minutes == null || seconds == null) {
      throw FormatException('Format waktu GTFS tidak valid: $value');
    }
    return hours * 3600 + minutes * 60 + seconds;
  }

  DateTime _parseGtfsDate(String value) {
    if (value.length != 8) {
      throw FormatException('Format tanggal GTFS tidak valid: $value');
    }
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(4, 6));
    final day = int.parse(value.substring(6, 8));
    return DateTime(year, month, day);
  }

  List<T> _mapRows<T>(
    String csvText, {
    required List<String> requiredColumns,
    required T Function(Map<String, String> row, int index) build,
  }) {
    final rows = _parseCsv(csvText);
    if (rows.isEmpty) {
      return <T>[];
    }
    final header = rows.first;
    final columnIndex = <String, int>{
      for (final column in requiredColumns) column: header.indexOf(column),
    };
    final missing = columnIndex.entries.where((entry) => entry.value == -1);
    if (missing.isNotEmpty) {
      throw FormatException(
        'Kolom GTFS wajib hilang: ${missing.map((e) => e.key).join(', ')}.',
      );
    }

    final results = <T>[];
    for (var i = 1; i < rows.length; i += 1) {
      final row = rows[i];
      if (row.length < header.length) {
        continue;
      }
      final byColumn = <String, String>{
        for (var c = 0; c < header.length; c += 1) header[c]: row[c],
      };
      results.add(build(byColumn, i - 1));
    }
    return results;
  }

  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;

    for (var index = 0; index < input.length; index += 1) {
      final char = input[index];
      if (char == '"') {
        if (quoted && index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index += 1;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(field.toString());
        field = StringBuffer();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' && index + 1 < input.length && input[index + 1] == '\n') {
          index += 1;
        }
        row.add(field.toString());
        field = StringBuffer();
        if (row.any((value) => value.isNotEmpty)) {
          rows.add(row);
        }
        row = <String>[];
      } else {
        field.write(char);
      }
    }

    if (quoted) {
      throw const FormatException('CSV GTFS memiliki kutip yang tidak ditutup.');
    }
    row.add(field.toString());
    if (row.any((value) => value.isNotEmpty)) {
      rows.add(row);
    }
    return rows;
  }
}
