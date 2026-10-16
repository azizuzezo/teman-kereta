/// Strips secrets and personal data from a log line before it is stored or
/// sent anywhere. Applied in [LogBuffer.add], so nothing sensitive ever reaches
/// the in-memory buffer, the log file or a support report.
///
/// What it removes, in this order:
/// 1. JWTs (Supabase anon/user tokens) -> `[JWT]`
/// 2. `Bearer xxx` tokens -> `Bearer [TOKEN]`
/// 3. `apikey`/`token`/`password`/`secret`/`authorization` pairs written as
///    `key=value`, `key: value` or JSON `"key":"value"` -> value `[REDACTED]`
/// 4. e-mail addresses -> `[EMAIL]`
/// 5. Indonesian and international phone numbers -> `[PHONE]`
/// 6. Latitude/longitude pairs are coarsened to 2 decimals (about 1 km)
///    rather than removed, so "near Manggarai" stays diagnosable.
String redactSecrets(String input) {
  if (input.isEmpty) {
    return input;
  }
  var out = input;
  out = out.replaceAllMapped(_jwt, (_) => '[JWT]');
  out = out.replaceAllMapped(_bearer, (_) => 'Bearer [TOKEN]');
  // A closing quote, if any, is not part of the match and stays in place.
  out = out.replaceAllMapped(
    _secretPair,
    (m) => '${m[1]}${m[2]}[REDACTED]',
  );
  out = out.replaceAllMapped(_email, (_) => '[EMAIL]');
  out = out.replaceAllMapped(_phone, (_) => '[PHONE]');
  out = out.replaceAllMapped(_coordinatePair, (m) {
    final lat = double.tryParse(m[1]!);
    final lon = double.tryParse(m[2]!);
    if (lat == null || lon == null) {
      return m[0]!;
    }
    return '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}~';
  });
  return out;
}

final RegExp _jwt = RegExp(
  r'eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]*',
);

final RegExp _bearer = RegExp(
  r'\bbearer\s+[A-Za-z0-9._~+/=-]{8,}',
  caseSensitive: false,
);

// Group 1 = key plus separator, group 2 = optional opening quote.
final RegExp _secretPair = RegExp(
  r'''((?:apikey|api_key|api-key|anon_?key|access_token|refresh_token|id_token|fcm_token|token|password|passwd|secret|authorization)["']?\s*[:=]\s*)(["']?)[^\s"',;&}\]]+''',
  caseSensitive: false,
);

final RegExp _email = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');

// +62 812-3456-7890, 62812..., 0812 3456 7890, and +<cc> international forms.
// Anchored so timestamps, uuids and plain integers are left alone.
final RegExp _phone = RegExp(
  r'(?<![\w.\-])(?:\+62|62|0)[\s\-]?8\d{1,3}[\s\-]?\d{3,4}[\s\-]?\d{2,5}(?![\w\-])'
  r'|(?<![\w.\-])\+\d{1,3}[\s\-]?\d{2,4}[\s\-]?\d{3,4}[\s\-]?\d{3,4}(?![\w\-])',
);

final RegExp _coordinatePair = RegExp(
  r'(?<![\d.])(-?\d{1,2}\.\d{3,})\s*[,;]\s*(-?\d{1,3}\.\d{3,})(?![\d])',
);
