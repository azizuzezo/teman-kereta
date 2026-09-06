import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../domain/entities/social_models.dart';
import 'widgets/user_row_tile.dart';

/// See the comment on `_followersProvider` in `followers_list_page.dart` for
/// why this is two queries instead of one nested-select join.
final _followingProvider = FutureProvider.family<List<UserSummary>, String>((
  ref,
  userId,
) async {
  final followRows =
      await Supabase.instance.client
              .from('user_follows')
              .select('followee_id')
              .eq('follower_id', userId)
          as List<dynamic>;
  final ids = followRows
      .map((row) => (row as Map<String, dynamic>)['followee_id'] as String)
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

class FollowingListPage extends ConsumerWidget {
  const FollowingListPage({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(_followingProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Mengikuti')),
      body: SafeArea(
        child: following.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const AppEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Gagal memuat',
            message: 'Terjadi kendala saat mengambil daftar mengikuti.',
          ),
          data: (users) {
            if (users.isEmpty) {
              return const AppEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'Belum mengikuti siapa pun',
                message: 'Cari pengguna lain untuk mulai mengikuti.',
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
