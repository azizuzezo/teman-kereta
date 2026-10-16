import '../../../domain/entities/social_models.dart';

/// Short Indonesian count for action rows: 950 -> "950", 1.250 -> "1,2 rb",
/// 15.400 -> "15 rb", 2.300.000 -> "2,3 jt". Never rounds up into the next
/// unit's label (999.999 stays "999 rb").
String compactCount(int value) {
  if (value < 1000) return '$value';
  if (value < 10000) {
    final tenths = value ~/ 100;
    final whole = tenths ~/ 10;
    final decimal = tenths % 10;
    return decimal == 0 ? '$whole rb' : '$whole,$decimal rb';
  }
  if (value < 1000000) return '${value ~/ 1000} rb';
  final tenths = value ~/ 100000;
  final whole = tenths ~/ 10;
  final decimal = tenths % 10;
  return decimal == 0 ? '$whole jt' : '$whole,$decimal jt';
}

/// Name and optional handle shown in a post or reply header. The handle is
/// dropped when the name already is the handle (no display name set) so the
/// same text is never printed twice.
({String name, String? handle}) forumAuthorLabel(UserSummary? author) {
  if (author == null) return (name: 'Pengguna Teman Kereta', handle: null);
  final username = author.username?.trim() ?? '';
  final display = author.displayName?.trim() ?? '';
  if (display.isNotEmpty) {
    return (name: display, handle: username.isEmpty ? null : '@$username');
  }
  if (username.isNotEmpty) return (name: '@$username', handle: null);
  return (name: 'Pengguna Teman Kereta', handle: null);
}

/// Strips characters that would break a PostgREST `or(...)` / `ilike` filter
/// string (commas and parentheses split filters, `%` and `*` are wildcards).
String sanitizeSearchQuery(String raw) {
  return raw.replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();
}
