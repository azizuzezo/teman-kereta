import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config/app_environment.dart';
import '../domain/subscription_entitlement.dart';

/// Real-time entitlement state for the premium station-reminder feature —
/// backed by `public.subscriptions` (written only by `claim_trial()` and the
/// `premium-check-payment` Edge Function, never directly by this client).
class SubscriptionController extends Notifier<SubscriptionEntitlement> {
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  SubscriptionEntitlement build() {
    if (!AppEnvironment.supabaseEnabled) {
      return SubscriptionEntitlement.unmetered;
    }

    ref.onDispose(() {
      final channel = _channel;
      if (channel != null) unawaited(channel.unsubscribe());
      unawaited(_authSubscription?.cancel());
    });

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _load(),
    );
    unawaited(_load());
    _subscribeToChanges();
    return SubscriptionEntitlement.none;
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = SubscriptionEntitlement.none;
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('subscriptions')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      state = row == null
          ? SubscriptionEntitlement.none
          : SubscriptionEntitlement.fromRow(row);
    } on Object {
      // Best-effort: keep whatever entitlement state was last known rather
      // than downgrading a real subscriber on a transient network error.
    }
  }

  void _subscribeToChanges() {
    _channel = Supabase.instance.client
        .channel('subscription_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'subscriptions',
          callback: (payload) => _load(),
        )
        .subscribe();
  }

  Future<void> refresh() => _load();
}

final subscriptionControllerProvider =
    NotifierProvider<SubscriptionController, SubscriptionEntitlement>(
      SubscriptionController.new,
    );
