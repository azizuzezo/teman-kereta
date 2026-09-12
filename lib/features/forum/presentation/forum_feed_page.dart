import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_environment.dart';
import '../../../core/widgets/empty_state.dart';
import 'forum_controller.dart';
import 'widgets/forum_post_card.dart';

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
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      unawaited(ref.read(forumControllerProvider.notifier).loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(forumControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Cari pengguna',
            icon: const Icon(Icons.person_search_outlined),
            onPressed: () => context.push('/social/search'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/forum/compose'),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: !AppEnvironment.supabaseEnabled
            ? const AppEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Forum tidak tersedia',
                message: 'Fitur forum memerlukan koneksi ke server.',
              )
            : Column(
                children: <Widget>[
                  const _LineFilterRow(),
                  Expanded(child: _buildFeed(feed)),
                ],
              ),
      ),
    );
  }

  Widget _buildFeed(AsyncValue<ForumFeedState> feed) {
    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Gagal memuat forum',
        message: 'Terjadi kendala saat mengambil postingan.',
        action: OutlinedButton(
          onPressed: () => ref.read(forumControllerProvider.notifier).refresh(),
          child: const Text('Coba lagi'),
        ),
      ),
      data: (state) {
        if (state.posts.isEmpty) {
          return AppEmptyState(
            icon: Icons.forum_outlined,
            title: 'Belum ada postingan',
            message: 'Jadilah yang pertama berbagi cerita seputar KRL.',
            action: FilledButton(
              onPressed: () => context.push('/forum/compose'),
              child: const Text('Buat postingan'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(forumControllerProvider.notifier).refresh(),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 28),
            itemCount: state.posts.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.posts.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return ForumPostCard(post: state.posts[index]);
            },
          ),
        );
      },
    );
  }
}

/// Horizontal "Semua" + one chip per active line, tinted with the line's own
/// brand color — filters [ForumController]'s feed via [ForumController.setLineFilter].
/// Renders nothing while lines are still loading or if there are none, same
/// as any other feature gated on real backend data rather than a placeholder.
class _LineFilterRow extends ConsumerWidget {
  const _LineFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(forumLineOptionsProvider).asData?.value;
    // Reading the feed's AsyncValue (not just the notifier) means this chip
    // row rebuilds and re-reads `.lineFilter` on every filter change, since
    // `setLineFilter` always drives the feed through a state transition.
    ref.watch(forumControllerProvider);
    final selected = ref.read(forumControllerProvider.notifier).lineFilter;
    if (lines == null || lines.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Semua'),
              selected: selected == null,
              onSelected: (_) => ref
                  .read(forumControllerProvider.notifier)
                  .setLineFilter(null),
            ),
          ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(line.code),
                selected: selected == line.id,
                selectedColor: (line.resolvedColor ?? theme.colorScheme.primary)
                    .withValues(alpha: 0.22),
                side: BorderSide(
                  color: selected == line.id
                      ? (line.resolvedColor ?? theme.colorScheme.primary)
                      : theme.colorScheme.outlineVariant,
                ),
                onSelected: (_) => ref
                    .read(forumControllerProvider.notifier)
                    .setLineFilter(line.id),
              ),
            ),
        ],
      ),
    );
  }
}
