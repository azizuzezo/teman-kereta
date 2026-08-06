import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/features/premium/domain/subscription_entitlement.dart';

void main() {
  final now = DateTime(2026, 8, 6, 12);

  test('trialing is entitled before trial_ends_at, not after', () {
    final active = SubscriptionEntitlement(
      status: SubscriptionStatus.trialing,
      trialEndsAt: now.add(const Duration(days: 1)),
    );
    final expired = SubscriptionEntitlement(
      status: SubscriptionStatus.trialing,
      trialEndsAt: now.subtract(const Duration(days: 1)),
    );

    expect(active.isEntitledAt(now), isTrue);
    expect(expired.isEntitledAt(now), isFalse);
  });

  test('active is entitled before current_period_end, not after', () {
    final active = SubscriptionEntitlement(
      status: SubscriptionStatus.active,
      currentPeriodEnd: now.add(const Duration(days: 1)),
    );
    final lapsed = SubscriptionEntitlement(
      status: SubscriptionStatus.active,
      currentPeriodEnd: now.subtract(const Duration(days: 1)),
    );

    expect(active.isEntitledAt(now), isTrue);
    expect(lapsed.isEntitledAt(now), isFalse);
  });

  test('expired and none are never entitled, even with future dates', () {
    final expired = SubscriptionEntitlement(
      status: SubscriptionStatus.expired,
      currentPeriodEnd: now.add(const Duration(days: 30)),
    );
    const none = SubscriptionEntitlement(status: SubscriptionStatus.none);

    expect(expired.isEntitledAt(now), isFalse);
    expect(none.isEntitledAt(now), isFalse);
  });

  test(
    'unmetered (no Supabase account system) is always entitled',
    () {
      expect(
        SubscriptionEntitlement.unmetered.isEntitledAt(now),
        isTrue,
      );
      expect(
        SubscriptionEntitlement.unmetered.isEntitledAt(
          now.add(const Duration(days: 3650)),
        ),
        isTrue,
      );
    },
  );

  test('fromRow parses a real subscriptions row shape', () {
    final entitlement = SubscriptionEntitlement.fromRow({
      'status': 'active',
      'trial_ends_at': null,
      'current_period_end': '2026-09-05T12:00:00.000Z',
    });

    expect(entitlement.status, SubscriptionStatus.active);
    expect(entitlement.trialEndsAt, isNull);
    expect(entitlement.currentPeriodEnd, DateTime.parse('2026-09-05T12:00:00.000Z'));
  });

  test('fromRow falls back to none for an unrecognized status', () {
    final entitlement = SubscriptionEntitlement.fromRow({'status': 'bogus'});
    expect(entitlement.status, SubscriptionStatus.none);
  });
}
