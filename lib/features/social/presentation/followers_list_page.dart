import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../domain/entities/social_models.dart';
import 'widgets/user_row_tile.dart';

/// Two separate queries (follow rows, then the matching user rows) rather
/// than a single nested-select join — `user_follows` has two foreign keys
/// into `public.users` (follower_id and followee_id), so a Postgrest nested
/// embed would need the exact generated constraint name to disambiguate.
/// This is simpler and doesn't depend on that naming detail.
final _followersProvider = FutureProvider.family<List<UserSummary>, String>((
  ref,
  userId,
) async {
  final followRows =
      await Supabase.instance.client
              .from('user_follows')
              .select('follower_id')
              .eq('followee_id', userId)
          as List<dynamic>;
  final ids = followRows
      .map((row) => (row as Map<String, dynamic>)['follower_id'] as String)
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
});

class FollowersListPage extends ConsumerWidget {
  const FollowersListPage({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followers = ref.watch(_followersProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Pengikut')),
      body: SafeArea(
        child: followers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const AppEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Gagal memuat',
            message: 'Terjadi kendala saat mengambil daftar pengikut.',
          ),
          data: (users) {
            if (users.isEmpty) {
              return const AppEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'Belum ada pengikut',
                message: 'Ketika ada yang mengikuti, mereka akan muncul di sini.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: users.length,
              itemBuilder: (context, index) => UserRowTile(user: users[index]),
            );
          },
        ),
      ),
    );
  }
}
