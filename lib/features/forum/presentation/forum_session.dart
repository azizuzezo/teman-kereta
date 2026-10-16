import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config/app_environment.dart';
import '../../../domain/entities/social_models.dart';
import '../../account/presentation/account_controller.dart';

/// Id of the signed-in account, or null when signed out or when Supabase is
/// off (mock builds, widget tests). Safe to call without Supabase initialised.
String? currentForumUserId() {
  if (!AppEnvironment.supabaseEnabled) return null;
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } on Object {
    return null;
  }
}

/// The signed-in account's own `public.users` row (name, handle, avatar), for
/// the composer row, the compose screen and the reply bar. Null when signed
/// out. Re-read each time a screen asks, so a freshly changed avatar shows up.
final myForumProfileProvider = FutureProvider.autoDispose<UserSummary?>((
  ref,
) async {
  final account = ref.watch(accountControllerProvider).asData?.value;
  if (account == null || !AppEnvironment.supabaseEnabled) return null;
  try {
    final row = await Supabase.instance.client
        .from('users')
        .select('id, username, display_name, avatar_url')
        .eq('id', account.id)
        .maybeSingle();
    return row == null ? null : UserSummary.fromJson(row);
  } on Object {
    return null;
  }
});
