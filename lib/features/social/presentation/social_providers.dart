import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/social_models.dart';

/// One user's public row, including follower/following counts. Auto-disposed
/// so opening a profile always shows current counts.
final userSummaryProvider = FutureProvider.autoDispose
    .family<UserSummary?, String>((ref, userId) async {
      final row = await Supabase.instance.client
          .from('users')
          .select(
            'id, username, display_name, avatar_url, '
            'follower_count, following_count',
          )
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      return UserSummary.fromJson(row);
    });

/// Two separate queries (follow rows, then the matching user rows) rather
/// than a single nested-select join: `user_follows` has two foreign keys into
/// `public.users` (follower_id and followee_id), so a Postgrest nested embed
/// would need the exact generated constraint name to disambiguate.
Future<List<UserSummary>> _usersFromFollowRows({
  required String filterColumn,
  required String pickColumn,
  required String userId,
}) async {
  final followRows =
      await Supabase.instance.client
              .from('user_follows')
              .select(pickColumn)
              .eq(filterColumn, userId)
          as List<dynamic>;
  final ids = followRows
      .map((row) => (row as Map<String, dynamic>)[pickColumn] as String)
      .toList();
  if (ids.isEmpty) return const <UserSummary>[];
  final userRows =
      await Supabase.instance.client
              .from('users')
              .select('id, username, display_name, avatar_url')
              .inFilter('id', ids)
          as List<dynamic>;
  return userRows
      .map((row) => UserSummary.fromJson(row as Map<String, dynamic>))
      .toList();
}

/// Accounts that follow [userId].
final userFollowersProvider = FutureProvider.autoDispose
    .family<List<UserSummary>, String>(
      (ref, userId) => _usersFromFollowRows(
        filterColumn: 'followee_id',
        pickColumn: 'follower_id',
        userId: userId,
      ),
    );

/// Accounts [userId] follows.
final userFollowingProvider = FutureProvider.autoDispose
    .family<List<UserSummary>, String>(
      (ref, userId) => _usersFromFollowRows(
        filterColumn: 'follower_id',
        pickColumn: 'followee_id',
        userId: userId,
      ),
    );
