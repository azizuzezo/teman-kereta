import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config/app_environment.dart';

/// Real read path for `public.app_config`, admin-managed via the Next.js
/// panel's Pengaturan page. Until this controller existed, editing that
/// table had zero effect on the mobile app (an explicit, honest note on
/// that same admin page said so). Read-only here by design — writes stay
/// service_role/admin-only, matching every other admin-managed table this
/// app consumes.
class AppConfigState {
  const AppConfigState({
    this.maintenanceMode = false,
    this.premiumPriceIdr = 15000,
    this.premiumPeriodDays = 30,
    this.premiumTrialDays = 14,
  });

  final bool maintenanceMode;

  /// Admin-editable via the panel's Settings page (`app_config.remote_config`
  /// key) — the defaults here match the seed in
  /// `20260806140000_premium_subscriptions.sql` and only matter before that
  /// migration's row has been fetched (or if it's ever unreachable).
  final int premiumPriceIdr;
  final int premiumPeriodDays;
  final int premiumTrialDays;
}

class AppConfigController extends Notifier<AppConfigState> {
  RealtimeChannel? _channel;

  @override
  AppConfigState build() {
    if (!AppEnvironment.supabaseEnabled) {
      return const AppConfigState();
    }

    ref.onDispose(() {
      final channel = _channel;
      if (channel != null) unawaited(channel.unsubscribe());
    });

    unawaited(_load());
    _subscribe();
    return const AppConfigState();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('app_config')
          .select('key, value')
          .inFilter('key', ['maintenance_mode', 'remote_config']);
      final byKey = {
        for (final row in rows) row['key'] as String: row['value'],
      };
      final remoteConfig = byKey['remote_config'];
      final config = remoteConfig is Map ? remoteConfig : const <String, Object?>{};
      const fallback = AppConfigState();
      state = AppConfigState(
        maintenanceMode: byKey['maintenance_mode'] == true,
        premiumPriceIdr:
            (config['premium_price_idr'] as num?)?.toInt() ??
            fallback.premiumPriceIdr,
        premiumPeriodDays:
            (config['premium_period_days'] as num?)?.toInt() ??
            fallback.premiumPeriodDays,
        premiumTrialDays:
            (config['premium_trial_days'] as num?)?.toInt() ??
            fallback.premiumTrialDays,
      );
    } on Object {
      // Best-effort: if app_config can't be reached, the app just behaves as
      // if maintenance mode is off (and premium pricing falls back to the
      // migration's seeded defaults) rather than blocking on a config fetch.
    }
  }

  void _subscribe() {
    _channel = Supabase.instance.client
        .channel('app_config_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_config',
          callback: (payload) => _load(),
        )
        .subscribe();
  }
}

final appConfigControllerProvider =
    NotifierProvider<AppConfigController, AppConfigState>(
      AppConfigController.new,
    );
