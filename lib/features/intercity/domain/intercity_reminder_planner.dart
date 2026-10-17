/// The "[n] kilometer lagi" reminders of an intercity ride.
///
/// The rider is told when 30, 15 and 10 km of rail are left. Distance, not
/// time: with no timetable there is no honest arrival time to count down to,
/// while the distance left along the rails is known at every fix. The planner
/// only decides *when* each one is due; playing it is up to the caller.
class IntercityReminderPlanner {
  IntercityReminderPlanner({
    this.thresholds = const <int>[30, 15, 10],
    this.marginKm = 0.3,
  }) : assert(thresholds.isNotEmpty),
       _fired = <int>{};

  /// Remaining rail distance in km at which a reminder is due, largest first.
  final List<int> thresholds;

  /// A reminder is raised this far before its mark, which covers the error of
  /// placing a fix on the track.
  final double marginKm;
  final Set<int> _fired;
  bool _seeded = false;

  bool hasFired(int km) => _fired.contains(km);

  /// Call with the rail distance left after each fix. Returns the reminder that
  /// is due now (its threshold in km), or null.
  ///
  /// - The first reading silently retires every reminder already inside it:
  ///   boarding with 20 km to go must not announce "30 kilometer lagi".
  /// - A reminder fires once, however much the reading wobbles around it.
  /// - If one reading crosses several (a GPS gap), only the nearest one is
  ///   announced; the earlier ones are stale.
  int? onRemainingKm(double remainingKm) {
    if (!_seeded) {
      _seeded = true;
      for (final t in thresholds) {
        if (remainingKm <= t) _fired.add(t);
      }
      return null;
    }
    int? due;
    for (final t in thresholds) {
      if (remainingKm <= t + marginKm && !_fired.contains(t)) {
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
