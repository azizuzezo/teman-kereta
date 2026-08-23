import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_logo.dart';
import 'forum_controller.dart';
import 'forum_models.dart';
import 'widgets/forum_post_card.dart';

class ForumPostDetailPage extends ConsumerStatefulWidget {
  const ForumPostDetailPage({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<ForumPostDetailPage> createState() =>
      _ForumPostDetailPageState();
}

class _ForumPostDetailPageState extends ConsumerState<ForumPostDetailPage> {
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    setState(() => _submitting = true);
    final error = await ref
        .read(forumControllerProvider.notifier)
        .addComment(widget.postId, body);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _commentController.clear();
    ref.invalidate(forumCommentsProvider(widget.postId));
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(forumPostProvider(widget.postId));
    final comments = ref.watch(forumCommentsProvider(widget.postId));

    return Scaffold(
      appBar: AppBar(title: const Text('Postingan')),
      body: SafeArea(
        child: post.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const AppEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Gagal memuat postingan',
            message: 'Terjadi kendala saat mengambil postingan ini.',
          ),
          data: (post) {
            if (post == null) {
              return const AppEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Postingan tidak ditemukan',
                message: 'Postingan ini mungkin sudah dihapus.',
              );
            }
            return Column(
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 12),
                    children: <Widget>[
                      ForumPostCard(post: post),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Komentar',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: comments.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (error, stack) => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Gagal memuat komentar.'),
                          ),
                          data: (list) {
                            if (list.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('Belum ada komentar. Jadi yang pertama!'),
                              );
                            }
                            return Column(
                              children: <Widget>[
                                for (final comment in list)
                                  _CommentTile(
                                    comment: comment,
                                    postId: widget.postId,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              hintText: 'Tulis komentar...',
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _submitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                onPressed: _submitComment,
                                icon: const Icon(Icons.send_rounded),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({required this.comment, required this.postId});

  final ForumComment comment;
  final String postId;

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  late final TextEditingController _editController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.comment.body);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _saveEdit() async {
    final body = _editController.text.trim();
    if (body.isEmpty) return;
    setState(() => _isSaving = true);
    final error = await ref
        .read(forumControllerProvider.notifier)
        .updateComment(widget.comment.id, body);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (error == null) _isEditing = false;
    });
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ref.invalidate(forumCommentsProvider(widget.postId));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus komentar?'),
        content: const Text('Komentar yang dihapus tidak dapat dikembalikan.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(forumControllerProvider.notifier).deleteComment(widget.comment.id);
      ref.invalidate(forumCommentsProvider(widget.postId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final author = comment.author;
    final hasAvatar = author?.avatarUrl != null && author!.avatarUrl!.isNotEmpty;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = currentUserId != null && currentUserId == comment.userId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            backgroundImage: hasAvatar
                ? CachedNetworkImageProvider(author.avatarUrl!)
                : null,
            child: hasAvatar ? null : const TkLogo(size: 20, showLabel: false),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: RichText(
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: Theme.of(context).textTheme.labelLarge,
                          children: <InlineSpan>[
                            TextSpan(
                              text: author?.resolvedName ?? 'Pengguna Teman Kereta',
                            ),
                            TextSpan(
                              text: '  ·  ${relativeTime(comment.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isOwner && !_isEditing)
                      PopupMenuButton<String>(
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'edit') {
                            setState(() {
                              _editController.text = comment.body;
                              _isEditing = true;
                            });
                          }
                          if (value == 'delete') unawaited(_confirmDelete());
                        },
                        itemBuilder: (context) => const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit komentar'),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Hapus komentar'),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                if (_isEditing) ...<Widget>[
                  TextField(
                    controller: _editController,
                    maxLength: 1000,
                    maxLines: null,
                    autofocus: true,
                    decoration: const InputDecoration(counterText: ''),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: _isSaving
                            ? null
                            : () => setState(() => _isEditing = false),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: _isSaving ? null : _saveEdit,
                        child: _isSaving
                            ? const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Simpan'),
                      ),
                    ],
                  ),
                ] else
                  Text(comment.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
