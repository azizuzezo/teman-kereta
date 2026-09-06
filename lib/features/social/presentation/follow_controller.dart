import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config/app_environment.dart';

/// Kept separate from `forum/` since [FollowButton] and the follow state it
/// reads are used outside forum context too (search results,
/// followers/following lists, another user's profile page).
class FollowController extends Notifier<void> {
  @override
  void build() {}

  Future<bool> isFollowing(String targetUserId) async {
    if (!AppEnvironment.supabaseEnabled) return false;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId == targetUserId) return false;
    try {
      final row = await Supabase.instance.client
          .from('user_follows')
          .select('follower_id')
          .eq('follower_id', userId)
          .eq('followee_id', targetUserId)
          .maybeSingle();
      return row != null;
    } on Object {
      return false;
    }
  }

  /// Returns an error message on failure, or null on success.
  Future<String?> toggleFollow(String targetUserId, bool currentlyFollowing) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 'Masuk untuk mengikuti pengguna lain.';
    if (userId == targetUserId) return null;
    try {
      if (currentlyFollowing) {
        await Supabase.instance.client
            .from('user_follows')
            .delete()
            .eq('follower_id', userId)
            .eq('followee_id', targetUserId);
      } else {
        await Supabase.instance.client.from('user_follows').insert(
          <String, Object?>{'follower_id': userId, 'followee_id': targetUserId},
        );
      }
      return null;
    } on Object {
      return 'Gagal memperbarui status ikuti. Coba lagi.';
    }
  }
}

final followControllerProvider = NotifierProvider<FollowController, void>(
  FollowController.new,
);

final isFollowingProvider = FutureProvider.family<bool, String>((ref, targetUserId) {
  return ref.read(followControllerProvider.notifier).isFollowing(targetUserId);
});
