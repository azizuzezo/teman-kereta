import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_environment.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../account/presentation/account_controller.dart';
import 'forum_controller.dart';
import 'forum_models.dart';
import 'forum_session.dart';
import 'widgets/forum_line_chip.dart';
import 'widgets/forum_post_card.dart';
import 'widgets/forum_skeletons.dart';

class ForumFeedPage extends ConsumerStatefulWidget {
  const ForumFeedPage({super.key});

  @override
  ConsumerState<ForumFeedPage> createState() => _ForumFeedPageState();
}

class _ForumFeedPageState extends ConsumerState<ForumFeedPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 320) {
      unawaited(ref.read(forumControllerProvider.notifier).loadMore());
    }
  }

  /// A short first page may not fill the screen, so there is nothing to
  /// scroll and [_onScroll] never fires; ask for the next page directly.
  void _fillViewportIfShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 0) {
        unawaited(ref.read(forumControllerProvider.notifier).loadMore());
      }
    });
  }

  Future<void> _pullToRefresh() async {
    final ok = await ref.read(forumControllerProvider.notifier).reload();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum bisa memuat ulang. Periksa koneksimu.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(forumControllerProvider);
    final controller = ref.read(forumControllerProvider.notifier);
    final filter = controller.filter;
    final enabled = AppEnvironment.supabaseEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum'),
        actions: <Widget>[
          if (enabled)
            IconButton(
              tooltip: 'Cari pengguna',
              icon: const Icon(Icons.search_rounded),
              onPressed: () => context.push('/social/search'),
            ),
        ],
      ),
      floatingActionButton: enabled
          ? FloatingActionButton.small(
              tooltip: 'Tulis postingan',
              onPressed: () => context.push('/forum/compose'),
              child: const Icon(Icons.edit_rounded),
            )
          : null,
      body: SafeArea(
        child: !enabled
            ? const AppEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Forum belum tersedia',
                message: 'Forum butuh koneksi ke server Teman Kereta.',
              )
            : Column(
                children: <Widget>[
                  _FeedTabs(
                    followingOnly: filter.followingOnly,
                    onChanged: (value) =>
                        controller.setFollowingOnly(value: value),
                  ),
                  const _LineFilterRow(),
                  Divider(height: 1, color: context.tk.border),
                  Expanded(child: _buildFeed(feed, filter)),
                ],
              ),
      ),
    );
  }

  Widget _buildFeed(AsyncValue<ForumFeedState> feed, ForumFeedFilter filter) {
    return feed.when(
      loading: () => const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: ForumPostSkeleton(),
      ),
      error: (error, stack) => TkErrorState(
        title: 'Forum gagal dimuat',
        message: 'Periksa koneksimu, lalu coba lagi.',
        onRetry: () => ref.read(forumControllerProvider.notifier).refresh(),
      ),
      data: (state) {
        _fillViewportIfShort();
        final tk = context.tk;
        return RefreshIndicator(
          onRefresh: _pullToRefresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              const SliverToBoxAdapter(child: _ComposerRow()),
              if (state.posts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyFeed(filter: filter),
                )
              else ...<Widget>[
                SliverList.separated(
                  itemCount: state.posts.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tk.border),
                  itemBuilder: (context, index) => ForumPostCard(
                    key: ValueKey<String>(state.posts[index].id),
                    post: state.posts[index],
                  ),
                ),
                SliverToBoxAdapter(child: Divider(height: 1, color: tk.border)),
                SliverToBoxAdapter(
                  child: state.hasMore
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : const SizedBox(height: 96),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// "Terbaru" / "Mengikuti": two equal tabs with an underline on the active
/// one. "Mengikuti" shows only accounts the signed-in user follows.
class _FeedTabs extends StatelessWidget {
  const _FeedTabs({required this.followingOnly, required this.onChanged});

  final bool followingOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _FeedTab(
            label: 'Terbaru',
            selected: !followingOnly,
            onTap: () => onChanged(false),
          ),
        ),
        Expanded(
          child: _FeedTab(
            label: 'Mengikuti',
            selected: followingOnly,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? tk.text : tk.textMuted,
                ),
              ),
              if (selected)
                Positioned(
                  bottom: 0,
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
        ),
      ),
    );
  }
}

/// "Semua jalur" plus one chip per active line, narrowing the feed via
/// [ForumController.setLineFilter]. Renders nothing while lines are loading or
/// if there are none.
class _LineFilterRow extends ConsumerWidget {
  const _LineFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(forumLineOptionsProvider).asData?.value;
    // Watching the feed makes this row re-read the selected line whenever the
    // filter changes, since a change always drives the feed through a reload.
    ref.watch(forumControllerProvider);
    final controller = ref.read(forumControllerProvider.notifier);
    final selected = controller.lineFilter;
    if (lines == null || lines.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: lines.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          if (index == 0) {
            return ForumLineChip(
              label: 'Semua jalur',
              selected: selected == null,
              onTap: () => controller.setLineFilter(null),
            );
          }
          final line = lines[index - 1];
          return ForumLineChip(
            label: line.code,
            semanticLabel: 'Jalur ${line.name}',
            color: line.resolvedColor,
            selected: selected == line.id,
            onTap: () => controller.setLineFilter(line.id),
          );
        },
      ),
    );
  }
}

/// "Apa yang terjadi di jalurmu?" row at the top of the feed. Opens the
/// compose screen (or the login screen when signed out).
class _ComposerRow extends ConsumerWidget {
  const _ComposerRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final signedIn = ref.watch(accountControllerProvider).asData?.value != null;
    final me = signedIn
        ? ref.watch(myForumProfileProvider).asData?.value
        : null;
    final name = me == null ? '' : (me.displayName ?? me.username ?? '');
    return Column(
      children: <Widget>[
        InkWell(
          onTap: () =>
              context.push(signedIn ? '/forum/compose' : '/account/login'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: <Widget>[
                  TkAvatar(name: name, imageUrl: me?.avatarUrl, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      signedIn
                          ? 'Apa yang terjadi di jalurmu?'
                          : 'Masuk untuk ikut bercerita',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: tk.textMuted),
                    ),
                  ),
                  Icon(Icons.edit_outlined, size: 20, color: tk.textMuted),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: tk.border),
      ],
    );
  }
}

class _EmptyFeed extends ConsumerWidget {
  const _EmptyFeed({required this.filter});

  final ForumFeedFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (filter.followingOnly) {
      final signedIn =
          ref.watch(accountControllerProvider).asData?.value != null;
      if (!signedIn) {
        return AppEmptyState(
          icon: Icons.people_outline_rounded,
          title: 'Masuk untuk melihat yang kamu ikuti',
          message: 'Daftar ikutanmu tersimpan di akunmu.',
          action: FilledButton(
            onPressed: () => context.push('/account/login'),
            child: const Text('Masuk'),
          ),
        );
      }
      return AppEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Belum ada kabar dari yang kamu ikuti',
        message: 'Ikuti pengguna lain supaya postingan mereka muncul di sini.',
        action: FilledButton(
          onPressed: () => context.push('/social/search'),
          child: const Text('Cari pengguna'),
        ),
      );
    }
    if (filter.lineId != null) {
      return AppEmptyState(
        icon: Icons.route_outlined,
        title: 'Belum ada postingan di jalur ini',
        message: 'Tulis yang pertama dan tandai jalurnya.',
        action: FilledButton(
          onPressed: () => context.push('/forum/compose'),
          child: const Text('Tulis postingan'),
        ),
      );
    }
    return AppEmptyState(
      icon: Icons.forum_outlined,
      title: 'Belum ada postingan',
      message: 'Jadi yang pertama bercerita soal perjalananmu.',
      action: FilledButton(
        onPressed: () => context.push('/forum/compose'),
        child: const Text('Tulis postingan'),
      ),
    );
  }
}
