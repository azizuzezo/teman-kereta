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
  const AppConfigState({this.maintenanceMode = false});

  final bool maintenanceMode;
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
          .inFilter('key', ['maintenance_mode']);
      final byKey = {
        for (final row in rows) row['key'] as String: row['value'],
      };
      state = AppConfigState(maintenanceMode: byKey['maintenance_mode'] == true);
    } on Object {
      // Best-effort: if app_config can't be reached, the app just behaves as
      // if maintenance mode is off rather than blocking on a config fetch.
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
