import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/relative_time.dart';
import '../../../../core/widgets/tk_logo.dart';
import '../../../social/presentation/widgets/follow_button.dart';
import '../forum_controller.dart';
import '../forum_models.dart';
import 'mentions.dart';

/// A single feed post rendered Instagram/Facebook-style: full-bleed photo,
/// a bold "N suka" line, an Instagram-caption-style "**username** body"
/// line, and a double-tap-the-photo-to-like gesture — used both by the
/// forum feed and (read-only, no like/comment actions needed there beyond
/// navigation) another user's profile page. Keeps its own optimistic like
/// state so it renders correctly even when the post isn't part of
/// [ForumController]'s current feed page (e.g. viewed from a profile).
class ForumPostCard extends ConsumerStatefulWidget {
  const ForumPostCard({required this.post, super.key});

  final ForumPost post;

  @override
  ConsumerState<ForumPostCard> createState() => _ForumPostCardState();
}

class _ForumPostCardState extends ConsumerState<ForumPostCard>
    with SingleTickerProviderStateMixin {
  late bool _liked;
  late int _likeCount;
  late String _body;
  late final AnimationController _heartBurstController;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.likedByMe;
    _likeCount = widget.post.likeCount;
    _body = widget.post.body;
    _heartBurstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  void didUpdateWidget(covariant ForumPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _liked = widget.post.likedByMe;
      _likeCount = widget.post.likeCount;
      _body = widget.post.body;
    }
  }

  @override
  void dispose() {
    _heartBurstController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
    });
    await ref
        .read(forumControllerProvider.notifier)
        .toggleLike(widget.post.id, wasLiked);
  }

  Future<void> _onDoubleTapImage() async {
    unawaited(_heartBurstController.forward(from: 0));
    if (!_liked) {
      await _toggleLike();
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Lihat postingan di Teman Kereta: '
            '"${widget.post.body}"',
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus postingan?'),
        content: const Text('Postingan yang dihapus tidak dapat dikembalikan.'),
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
      await ref.read(forumControllerProvider.notifier).deletePost(widget.post.id);
    }
  }

  Future<void> _editPost(BuildContext context) async {
    final controller = TextEditingController(text: _body);
    final formKey = GlobalKey<FormState>();
    final newBody = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit postingan'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLines: 6,
            minLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(hintText: 'Tulis sesuatu...'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Postingan tidak boleh kosong.';
              }
              return null;
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (newBody == null || newBody == _body) return;
    final error = await ref
        .read(forumControllerProvider.notifier)
        .updatePost(widget.post.id, newBody);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _body = newBody);
    // Refreshes the post-detail page's copy (fed by a separate provider from
    // the feed's), which the feed itself already picked up above via the
    // controller state update.
    ref.invalidate(forumPostProvider(widget.post.id));
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = post.author;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = currentUserId != null && currentUserId == post.userId;
    final hasAvatar = author?.avatarUrl != null && author!.avatarUrl!.isNotEmpty;
    final authorName = author?.resolvedName ?? 'Pengguna Teman Kereta';
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // --- Header: avatar, name, timestamp, follow/menu ---
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: <Widget>[
              InkWell(
                onTap: () => context.push('/social/user/${post.userId}'),
                borderRadius: BorderRadius.circular(20),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: hasAvatar
                      ? CachedNetworkImageProvider(author.avatarUrl!)
                      : null,
                  child: hasAvatar
                      ? null
                      : const TkLogo(size: 22, showLabel: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => context.push('/social/user/${post.userId}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        authorName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        relativeTime(post.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isOwner) FollowButton(targetUserId: post.userId),
              if (isOwner)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (value) {
                    if (value == 'edit') unawaited(_editPost(context));
                    if (value == 'delete') unawaited(_confirmDelete(context));
                  },
                  itemBuilder: (context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit postingan'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Hapus postingan'),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // --- Caption / post text ---
        if (_body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: MentionText(
              _body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),

        // --- Full-bleed photo with double-tap-to-like ---
        if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
          GestureDetector(
            onDoubleTap: _onDoubleTapImage,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => const AspectRatio(
                    aspectRatio: 1,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
                AnimatedBuilder(
                  animation: _heartBurstController,
                  builder: (context, child) {
                    final t = _heartBurstController.value;
                    // Quick pop-in then fade-out, Instagram-style.
                    final scale = t < 0.4 ? (t / 0.4) : 1.0;
                    final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
                    if (t == 0 || t == 1) return const SizedBox.shrink();
                    return Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.7 + 0.5 * scale,
                        child: Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 96,
                          shadows: <Shadow>[
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

        // --- Action row: like, comment, share ---
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: _toggleLike,
                icon: Icon(
                  _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _liked ? theme.colorScheme.error : null,
                ),
              ),
              IconButton(
                onPressed: () => context.push('/forum/post/${post.id}'),
                icon: const Icon(Icons.mode_comment_outlined),
              ),
              IconButton(
                onPressed: _share,
                icon: const Icon(Icons.send_outlined),
              ),
            ],
          ),
        ),

        // --- Like count ---
        if (_likeCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(
              '$_likeCount suka',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

        // --- Comments link ---
        if (post.commentCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: InkWell(
              onTap: () => context.push('/forum/post/${post.id}'),
              child: Text(
                'Lihat semua ${post.commentCount} komentar',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 10),

        const Divider(height: 1, thickness: 1),
      ],
    );
  }
}
