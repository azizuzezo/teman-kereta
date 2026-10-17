/// The "[minutes] menit lagi" reminders of an intercity ride.
///
/// The rider is told 30, 15 and 10 minutes before arriving. The planner only
/// decides *when* each one is due; playing it is up to the caller.
class IntercityReminderPlanner {
  IntercityReminderPlanner({
    this.thresholds = const <int>[30, 15, 10],
    this.marginMinutes = 1.0,
  }) : assert(thresholds.isNotEmpty),
       _fired = <int>{};

  /// Minutes before arrival, largest first.
  final List<int> thresholds;

  /// A reminder is raised this long before its mark. With no timetable the
  /// estimate can be off either way, and an announcement that comes late is
  /// worse than one that comes a minute early.
  final double marginMinutes;
  final Set<int> _fired;
  bool _seeded = false;

  bool hasFired(int minutes) => _fired.contains(minutes);

  /// Call with each new estimate. Returns the reminder that is due now, or
  /// null.
  ///
  /// - The first estimate silently retires every reminder already inside it:
  ///   boarding with 20 minutes to go must not announce "30 menit lagi".
  /// - A reminder fires once, however much the estimate wobbles around it.
  /// - If one update crosses several (a GPS gap), only the nearest one is
  ///   announced; the earlier ones are stale.
  int? onEta(Duration eta) {
    final minutesLeft = eta.inMilliseconds / 60000.0;
    if (!_seeded) {
      _seeded = true;
      for (final t in thresholds) {
        if (minutesLeft <= t) _fired.add(t);
      }
      return null;
    }
    int? due;
    for (final t in thresholds) {
      if (minutesLeft <= t + marginMinutes && !_fired.contains(t)) {
        if (due == null || t < due) due = t;
      }
    }
    if (due == null) return null;
    for (final t in thresholds) {
      if (t >= due) _fired.add(t);
    }
    return due;
  }
}
