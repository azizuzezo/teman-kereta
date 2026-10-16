import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../domain/entities/social_models.dart';
import '../../forum/presentation/forum_controller.dart';
import '../../forum/presentation/forum_format.dart';
import '../../forum/presentation/forum_session.dart';
import '../../forum/presentation/widgets/forum_moderation_actions.dart';
import '../../forum/presentation/widgets/forum_post_card.dart';
import '../../forum/presentation/widgets/forum_skeletons.dart';
import 'social_providers.dart';
import 'widgets/follow_button.dart';

/// Another user's public profile: avatar, name, @username, follower and
/// following counts (each opens its list), a follow button and their posts.
/// Also reachable for the signed-in user's own id, where the follow button and
/// the block action simply don't appear.
class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({required this.userId, super.key});

  final String userId;

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(userSummaryProvider(userId))
      ..invalidate(forumUserPostsProvider(userId));
    try {
      await ref.read(forumUserPostsProvider(userId).future);
    } on Object {
      // The posts section shows its own error state.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userSummaryProvider(userId));
    final user = userAsync.asData?.value;
    final canBlock =
        user != null &&
        currentForumUserId() != null &&
        currentForumUserId() != userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user?.username != null && user!.username!.isNotEmpty
              ? '@${user.username}'
              : 'Profil',
        ),
        actions: <Widget>[
          if (canBlock)
            PopupMenuButton<String>(
              tooltip: 'Opsi profil',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (value) async {
                if (value != 'block') return;
                final blocked = await blockForumUser(
                  context,
                  ref,
                  userId: userId,
                  displayName: forumAuthorLabel(user).name,
                );
                if (blocked && context.mounted) {
                  unawaited(Navigator.of(context).maybePop());
                }
              },
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                forumMenuItem(
                  context,
                  value: 'block',
                  icon: Icons.block_rounded,
                  label: 'Blokir pengguna',
                  destructive: true,
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const _ProfileSkeleton(),
          error: (error, stack) => TkErrorState(
            title: 'Profil gagal dimuat',
            message: 'Periksa koneksimu, lalu coba lagi.',
            onRetry: () => ref.invalidate(userSummaryProvider(userId)),
          ),
          data: (user) {
            if (user == null) {
              return const AppEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Pengguna tidak ditemukan',
                message: 'Akun ini mungkin sudah dihapus.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverToBoxAdapter(child: _ProfileHeader(user: user)),
                  const SliverToBoxAdapter(child: _PostsTabHeader()),
                  ..._postSlivers(context, ref),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _postSlivers(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final posts = ref.watch(forumUserPostsProvider(userId));
    return posts.when(
      loading: () => const <Widget>[
        SliverToBoxAdapter(child: ForumPostSkeleton(count: 3)),
      ],
      error: (error, stack) => <Widget>[
        SliverToBoxAdapter(
          child: TkErrorState(
            title: 'Postingan gagal dimuat',
            message: 'Periksa koneksimu, lalu coba lagi.',
            onRetry: () => ref.invalidate(forumUserPostsProvider(userId)),
          ),
        ),
      ],
      data: (list) {
        if (list.isEmpty) {
          return const <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: AppEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'Belum ada postingan',
                  message: 'Postingan pengguna ini akan muncul di sini.',
                ),
              ),
            ),
          ];
        }
        return <Widget>[
          SliverList.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: tk.border),
            itemBuilder: (context, index) => ForumPostCard(
              key: ValueKey<String>(list[index].id),
              post: list[index],
            ),
          ),
          SliverToBoxAdapter(child: Divider(height: 1, color: tk.border)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ];
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserSummary user;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final label = forumAuthorLabel(user);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineMedium,
                    ),
                    if (label.handle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          label.handle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: tk.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              TkAvatar(name: label.name, imageUrl: user.avatarUrl, size: 76),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              _CountLink(
                count: user.followerCount ?? 0,
                label: 'Pengikut',
                onTap: () => context.push('/social/followers/${user.id}'),
              ),
              const SizedBox(width: 20),
              _CountLink(
                count: user.followingCount ?? 0,
                label: 'Mengikuti',
                onTap: () => context.push('/social/following/${user.id}'),
              ),
            ],
          ),
          FollowButton(targetUserId: user.id, expanded: true),
        ],
      ),
    );
  }
}

class _CountLink extends StatelessWidget {
  const _CountLink({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$count $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(compactCount(count), style: textTheme.titleMedium),
              const SizedBox(width: 6),
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(color: tk.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single tab ("Postingan") with the same underline as the feed tabs, so the
/// list below reads as a tab's content.
class _PostsTabHeader extends StatelessWidget {
  const _PostsTabHeader();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      height: 48,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: tk.border),
          bottom: BorderSide(color: tk.border),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Postingan',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: tk.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TkSkeleton(height: 24, width: 180),
                      SizedBox(height: 10),
                      TkSkeleton(height: 14, width: 100),
                      SizedBox(height: 28),
                      TkSkeleton(height: 14, width: 160),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                TkSkeleton(height: 76, width: 76, radius: 38),
              ],
            ),
          ),
          ForumPostSkeleton(count: 3),
        ],
      ),
    );
  }
}
