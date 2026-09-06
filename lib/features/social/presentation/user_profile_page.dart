import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_logo.dart';
import '../../../domain/entities/social_models.dart';
import '../../forum/presentation/forum_models.dart';
import '../../forum/presentation/widgets/forum_post_card.dart';
import 'widgets/follow_button.dart';

final _userSummaryProvider = FutureProvider.family<UserSummary?, String>((
  ref,
  userId,
) async {
  final row = await Supabase.instance.client
      .from('users')
      .select('id, username, display_name, avatar_url, follower_count, following_count')
      .eq('id', userId)
      .maybeSingle();
  if (row == null) return null;
  return UserSummary.fromJson(row);
});

final _userPostsProvider = FutureProvider.family<List<ForumPost>, String>((
  ref,
  userId,
) async {
  final rows =
      await Supabase.instance.client
              .from('forum_posts')
              .select('*, users(username, display_name, avatar_url)')
              .eq('user_id', userId)
              .eq('status', 'visible')
              .order('created_at', ascending: false)
          as List<dynamic>;
  return rows
      .map((row) => ForumPost.fromJson(row as Map<String, dynamic>))
      .toList();
});

/// Shows another user's public profile (display name, avatar,
/// follower/following counts, their posts). Also reachable for the
/// signed-in user's own id — the [FollowButton] simply renders nothing then.
class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_userSummaryProvider(userId));
    final postsAsync = ref.watch(_userPostsProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profil pengguna')),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const AppEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Gagal memuat profil',
            message: 'Terjadi kendala saat mengambil data pengguna ini.',
          ),
          data: (user) {
            if (user == null) {
              return const AppEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Pengguna tidak ditemukan',
                message: 'Akun ini mungkin sudah dihapus.',
              );
            }
            final hasAvatar =
                user.avatarUrl != null && user.avatarUrl!.isNotEmpty;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: hasAvatar
                          ? CachedNetworkImageProvider(user.avatarUrl!)
                          : null,
                      child: hasAvatar
                          ? null
                          : const TkLogo(size: 40, showLabel: false),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            user.resolvedName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (user.username != null && user.username!.isNotEmpty)
                            Text('@${user.username}'),
                        ],
                      ),
                    ),
                    FollowButton(targetUserId: user.id),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    _StatBlock(
                      count: user.followerCount ?? 0,
                      label: 'Pengikut',
                      onTap: () => context.push('/social/followers/${user.id}'),
                    ),
                    const SizedBox(width: 24),
                    _StatBlock(
                      count: user.followingCount ?? 0,
                      label: 'Mengikuti',
                      onTap: () => context.push('/social/following/${user.id}'),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Text('Postingan', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                postsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) =>
                      const Text('Gagal memuat postingan pengguna ini.'),
                  data: (posts) {
                    if (posts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Belum ada postingan.'),
                      );
                    }
                    return Column(
                      children: <Widget>[
                        for (final post in posts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ForumPostCard(post: post),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '$count',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
