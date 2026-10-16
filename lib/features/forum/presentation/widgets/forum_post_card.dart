import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/tk_components.dart';
import '../../../social/presentation/widgets/follow_button.dart';
import '../forum_controller.dart';
import '../forum_format.dart';
import '../forum_models.dart';
import '../forum_session.dart';
import 'forum_byline.dart';
import 'forum_line_chip.dart';
import 'forum_moderation_actions.dart';
import 'mentions.dart';

/// A forum post in the social-feed layout: avatar on the left, then name,
/// @username and time on one line, the text with mentions highlighted, an
/// optional photo and an action row (like, reply, share). Posts are separated
/// by hairlines supplied by the list, not by boxes.
///
/// With [threaded] the card becomes the head of a conversation on the detail
/// page: larger text, full body, a follow button, no tap-to-open, and (with
/// [threadLine]) a vertical line from the avatar down to the first reply.
///
/// Keeps its own optimistic like state so it renders correctly even when the
/// post isn't part of [ForumController]'s current feed page (e.g. viewed from
/// a profile).
class ForumPostCard extends ConsumerStatefulWidget {
  const ForumPostCard({
    required this.post,
    super.key,
    this.threaded = false,
    this.threadLine = false,
  });

  final ForumPost post;
  final bool threaded;
  final bool threadLine;

  @override
  ConsumerState<ForumPostCard> createState() => _ForumPostCardState();
}

class _ForumPostCardState extends ConsumerState<ForumPostCard>
    with TickerProviderStateMixin {
  late bool _liked;
  late int _likeCount;
  late String _body;
  late final AnimationController _likePop;
  late final AnimationController _heartBurst;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.likedByMe;
    _likeCount = widget.post.likeCount;
    _body = widget.post.body;
    _likePop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _heartBurst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  void didUpdateWidget(covariant ForumPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final post = widget.post;
    if (oldWidget.post.id != post.id) {
      _liked = post.likedByMe;
      _likeCount = post.likeCount;
      _body = post.body;
    } else {
      if (oldWidget.post.likedByMe != post.likedByMe ||
          oldWidget.post.likeCount != post.likeCount) {
        _liked = post.likedByMe;
        _likeCount = post.likeCount;
      }
      if (oldWidget.post.body != post.body) _body = post.body;
    }
  }

  @override
  void dispose() {
    _likePop.dispose();
    _heartBurst.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  Future<void> _toggleLike() async {
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
    });
    if (!wasLiked && !_reduceMotion) unawaited(_likePop.forward(from: 0));
    await ref
        .read(forumControllerProvider.notifier)
        .toggleLike(widget.post.id, wasLiked);
  }

  Future<void> _onDoubleTapImage() async {
    if (!_reduceMotion) unawaited(_heartBurst.forward(from: 0));
    if (!_liked) await _toggleLike();
  }

  Future<void> _share() async {
    final name = forumAuthorLabel(widget.post.author).name;
    await SharePlus.instance.share(
      ShareParams(text: '$name di Teman Kereta: "$_body"'),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus postingan?'),
        content: const Text(
          'Postingan dan semua balasannya akan hilang. '
          'Ini tidak bisa dibatalkan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.tk.danger,
              foregroundColor: dialogContext.tk.onAccent,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(forumControllerProvider.notifier).deletePost(widget.post.id);
    if (widget.threaded && mounted) unawaited(Navigator.of(context).maybePop());
  }

  Future<void> _editPost() async {
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
            decoration: const InputDecoration(hintText: 'Tulis sesuatu'),
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
    controller.dispose();
    if (newBody == null || newBody == _body || !mounted) return;
    final error = await ref
        .read(forumControllerProvider.notifier)
        .updatePost(widget.post.id, newBody);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _body = newBody);
    // Refreshes the post-detail page's copy (fed by a separate provider from
    // the feed's), which the feed itself already picked up via the
    // controller state update.
    ref.invalidate(forumPostProvider(widget.post.id));
  }

  void _openPost() => context.push('/forum/post/${widget.post.id}');

  void _openProfile() => context.push('/social/user/${widget.post.userId}');

  void _onMenu(String value, String authorName) {
    switch (value) {
      case 'edit':
        unawaited(_editPost());
      case 'delete':
        unawaited(_confirmDelete());
      case 'report':
        unawaited(reportForumContent(context, ref, postId: widget.post.id));
      case 'block':
        unawaited(
          blockForumUser(
            context,
            ref,
            userId: widget.post.userId,
            displayName: authorName,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final post = widget.post;
    final threaded = widget.threaded;
    final label = forumAuthorLabel(post.author);
    final isOwner = currentForumUserId() == post.userId;
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;

    final avatar = Semantics(
      button: true,
      label: 'Buka profil ${label.name}',
      excludeSemantics: true,
      child: InkResponse(
        onTap: _openProfile,
        radius: 26,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: TkAvatar(
              name: label.name,
              imageUrl: post.author?.avatarUrl,
              size: 40,
            ),
          ),
        ),
      ),
    );

    final header = Padding(
      padding: const EdgeInsets.only(right: 44),
      child: ForumByline(
        name: label.name,
        handle: label.handle,
        time: post.createdAt,
        onTap: _openProfile,
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        header,
        if (_body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 16),
            child: MentionText(
              _body,
              maxLines: threaded ? null : 12,
              style: (threaded ? textTheme.bodyLarge : textTheme.bodyMedium)
                  ?.copyWith(color: tk.text),
            ),
          ),
        if (post.lineId != null) _PostLineTag(lineId: post.lineId!),
        if (hasImage)
          Padding(
            padding: const EdgeInsets.only(top: 10, right: 16),
            child: _PostImage(
              url: post.imageUrl!,
              burst: _heartBurst,
              onTap: threaded ? null : _openPost,
              onDoubleTap: _onDoubleTapImage,
            ),
          ),
        Transform.translate(
          offset: const Offset(-12, 0),
          child: Row(
            children: <Widget>[
              _ActionButton(
                label: _likeCount > 0 ? compactCount(_likeCount) : null,
                semanticLabel: _liked
                    ? 'Batal suka, $_likeCount suka'
                    : 'Suka, $_likeCount suka',
                color: _liked ? tk.accent : tk.textMuted,
                onTap: _toggleLike,
                icon: ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.3).animate(
                    CurvedAnimation(parent: _likePop, curve: const _PopCurve()),
                  ),
                  child: Icon(
                    _liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 22,
                    color: _liked ? tk.accent : tk.textMuted,
                  ),
                ),
              ),
              _ActionButton(
                label: post.commentCount > 0
                    ? compactCount(post.commentCount)
                    : null,
                semanticLabel: 'Balas, ${post.commentCount} balasan',
                color: tk.textMuted,
                onTap: threaded ? null : _openPost,
                icon: Icon(
                  Icons.mode_comment_outlined,
                  size: 22,
                  color: tk.textMuted,
                ),
              ),
              _ActionButton(
                semanticLabel: 'Bagikan postingan',
                color: tk.textMuted,
                onTap: _share,
                icon: Icon(
                  Icons.ios_share_rounded,
                  size: 22,
                  color: tk.textMuted,
                ),
              ),
              if (threaded && !isOwner) ...<Widget>[
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FollowButton(targetUserId: post.userId),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final menu = PopupMenuButton<String>(
      tooltip: 'Opsi postingan',
      icon: Icon(Icons.more_horiz_rounded, color: tk.textMuted),
      onSelected: (value) => _onMenu(value, label.name),
      itemBuilder: (context) => isOwner
          ? <PopupMenuEntry<String>>[
              forumMenuItem(
                context,
                value: 'edit',
                icon: Icons.edit_outlined,
                label: 'Edit postingan',
              ),
              forumMenuItem(
                context,
                value: 'delete',
                icon: Icons.delete_outline_rounded,
                label: 'Hapus postingan',
                destructive: true,
              ),
            ]
          : forumModerationMenuItems(context),
    );

    final Widget plainRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        avatar,
        const SizedBox(width: 8),
        Expanded(child: details),
      ],
    );
    // The thread line is laid over the row instead of sized with
    // IntrinsicHeight, so it follows the text height without the intrinsic
    // pass (which the byline's LayoutBuilder cannot answer).
    final Widget row = threaded && widget.threadLine
        ? Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              plainRow,
              // Runs on past the cell's bottom padding to meet the first
              // reply's avatar.
              Positioned(
                left: 23,
                top: 50,
                bottom: -24,
                width: 2,
                child: ColoredBox(color: tk.border),
              ),
            ],
          )
        : plainRow;

    final content = Stack(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 0, threaded ? 8 : 0),
          child: row,
        ),
        Positioned(top: 4, right: 4, child: menu),
      ],
    );

    return Semantics(
      container: true,
      child: threaded ? content : InkWell(onTap: _openPost, child: content),
    );
  }
}

/// 0 -> 1 -> 0 hump used for the like "pop" so the heart returns to size.
class _PopCurve extends Curve {
  const _PopCurve();

  @override
  double transformInternal(double t) => math.sin(t * math.pi);
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.color,
    required this.onTap,
    this.label,
  });

  final Widget icon;
  final String? label;
  final String semanticLabel;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                icon,
                if (label != null) ...<Widget>[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: color),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The post's line tag, resolved through [forumLineOptionsByIdProvider].
/// Renders nothing while lines are loading or if the id doesn't resolve (a
/// line deactivated after the post was made).
class _PostLineTag extends ConsumerWidget {
  const _PostLineTag({required this.lineId});

  final String lineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final option = ref
        .watch(forumLineOptionsByIdProvider)
        .asData
        ?.value[lineId];
    if (option == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ForumLineChip(label: option.code, color: option.resolvedColor),
      ),
    );
  }
}

class _PostImage extends StatelessWidget {
  const _PostImage({
    required this.url,
    required this.burst,
    required this.onDoubleTap,
    required this.onTap,
  });

  final String url;
  final Animation<double> burst;
  final VoidCallback? onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      image: true,
      label: 'Foto postingan. Ketuk dua kali untuk menyukai.',
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TkRadius.control),
            border: Border.all(color: tk.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ColoredBox(color: tk.surfaceAlt),
                  ),
                  errorWidget: (context, url, error) => AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ColoredBox(
                      color: tk.surfaceAlt,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: tk.textMuted,
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: burst,
                  builder: (context, child) {
                    final t = burst.value;
                    if (t == 0 || t == 1) return const SizedBox.shrink();
                    final scale = t < 0.4 ? t / 0.4 : 1.0;
                    final opacity = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
                    return Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.7 + 0.5 * scale,
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 88,
                          shadows: <Shadow>[
                            Shadow(color: Colors.black38, blurRadius: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
