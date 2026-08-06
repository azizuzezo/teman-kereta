enum SubscriptionStatus { trialing, active, expired, none }

/// Mirrors one row of `public.subscriptions` — see
/// `20260806140000_premium_subscriptions.sql`. Gates the "reminder N
/// stasiun sebelum tujuan" notification (`ActiveTripController`) and drives
/// `PremiumPaywallPage`'s status copy.
class SubscriptionEntitlement {
  const SubscriptionEntitlement({
    required this.status,
    this.trialEndsAt,
    this.currentPeriodEnd,
  });

  factory SubscriptionEntitlement.fromRow(Map<String, Object?> row) {
    DateTime? parse(Object? value) =>
        value is String ? DateTime.parse(value) : null;
    return SubscriptionEntitlement(
      status: switch (row['status']) {
        'trialing' => SubscriptionStatus.trialing,
        'active' => SubscriptionStatus.active,
        'expired' => SubscriptionStatus.expired,
        _ => SubscriptionStatus.none,
      },
      trialEndsAt: parse(row['trial_ends_at']),
      currentPeriodEnd: parse(row['current_period_end']),
    );
  }

  static const none = SubscriptionEntitlement(status: SubscriptionStatus.none);

  /// No Supabase account system in this build mode (`mock`/`gtfs` without
  /// Supabase) — nothing to gate, so the premium feature behaves as if
  /// already entitled rather than dangling on an account system that
  /// doesn't exist here.
  static const unmetered = SubscriptionEntitlement(status: SubscriptionStatus.active);

  final SubscriptionStatus status;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;

  bool isEntitledAt(DateTime now) {
    return switch (status) {
      SubscriptionStatus.trialing =>
        trialEndsAt != null && now.isBefore(trialEndsAt!),
      // A null currentPeriodEnd on an "active" row only ever happens for
      // [unmetered] (no Supabase account system to gate against at all) —
      // real paid periods always have one set by premium-check-payment.
      SubscriptionStatus.active =>
        currentPeriodEnd == null || now.isBefore(currentPeriodEnd!),
      SubscriptionStatus.expired || SubscriptionStatus.none => false,
    };
  }

  DateTime? get expiresAt =>
      status == SubscriptionStatus.trialing ? trialEndsAt : currentPeriodEnd;
}
