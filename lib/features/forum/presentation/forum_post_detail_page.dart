import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import 'forum_controller.dart';
import 'forum_format.dart';
import 'forum_models.dart';
import 'forum_session.dart';
import 'widgets/forum_byline.dart';
import 'widgets/forum_moderation_actions.dart';
import 'widgets/forum_post_card.dart';
import 'widgets/forum_skeletons.dart';
import 'widgets/mentions.dart';

const _maxReplyLength = 1000;

class ForumPostDetailPage extends ConsumerStatefulWidget {
  const ForumPostDetailPage({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<ForumPostDetailPage> createState() =>
      _ForumPostDetailPageState();
}

class _ForumPostDetailPageState extends ConsumerState<ForumPostDetailPage> {
  final _replyController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _replyController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _replyController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  Future<void> _submitReply() async {
    final body = _replyController.text.trim();
    if (body.isEmpty || _submitting) return;
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
    _replyController.clear();
    FocusScope.of(context).unfocus();
    ref
      ..invalidate(forumCommentsProvider(widget.postId))
      ..invalidate(forumPostProvider(widget.postId));
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(forumPostProvider(widget.postId))
      ..invalidate(forumCommentsProvider(widget.postId));
    try {
      await ref.read(forumCommentsProvider(widget.postId).future);
    } on Object {
      // The list shows its own error state with a retry action.
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(forumPostProvider(widget.postId));
    final comments = ref.watch(forumCommentsProvider(widget.postId));
    final tk = context.tk;

    return Scaffold(
      appBar: AppBar(title: const Text('Postingan')),
      body: SafeArea(
        child: post.when(
          loading: () => const SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            child: ForumPostSkeleton(count: 3),
          ),
          error: (error, stack) => TkErrorState(
            title: 'Postingan gagal dimuat',
            message: 'Periksa koneksimu, lalu coba lagi.',
            onRetry: () => ref.invalidate(forumPostProvider(widget.postId)),
          ),
          data: (post) {
            if (post == null) {
              return const AppEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Postingan tidak ditemukan',
                message: 'Postingan ini mungkin sudah dihapus.',
              );
            }
            final replies = comments.asData?.value;
            return Column(
              children: <Widget>[
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      children: <Widget>[
                        ForumPostCard(
                          post: post,
                          threaded: true,
                          threadLine: replies != null && replies.isNotEmpty,
                        ),
                        ..._buildReplies(context, comments),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: tk.border),
                _ReplyBar(
                  controller: _replyController,
                  submitting: _submitting,
                  onSend: _submitReply,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildReplies(
    BuildContext context,
    AsyncValue<List<ForumComment>> comments,
  ) {
    final tk = context.tk;
    return comments.when(
      loading: () => <Widget>[
        Divider(height: 1, color: tk.border),
        const ForumPostSkeleton(count: 2),
      ],
      error: (error, stack) => <Widget>[
        Divider(height: 1, color: tk.border),
        TkErrorState(
          title: 'Balasan gagal dimuat',
          message: 'Periksa koneksimu, lalu coba lagi.',
          onRetry: () => ref.invalidate(forumCommentsProvider(widget.postId)),
        ),
      ],
      data: (list) {
        if (list.isEmpty) {
          return <Widget>[
            Divider(height: 1, color: tk.border),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AppEmptyState(
                icon: Icons.mode_comment_outlined,
                title: 'Belum ada balasan',
                message: 'Jadi yang pertama membalas.',
              ),
            ),
          ];
        }
        return <Widget>[
          for (var i = 0; i < list.length; i++) ...<Widget>[
            _ReplyTile(
              key: ValueKey<String>(list[i].id),
              comment: list[i],
              postId: widget.postId,
            ),
            if (i < list.length - 1)
              Divider(height: 1, indent: 60, color: tk.border),
          ],
          Divider(height: 1, color: tk.border),
        ];
      },
    );
  }
}

/// Sticky reply bar: the viewer's avatar, a rounded multiline field with
/// @-suggestions above it, a remaining-characters hint near the limit, and a
/// send button that turns into a spinner while sending.
class _ReplyBar extends ConsumerWidget {
  const _ReplyBar({
    required this.controller,
    required this.submitting,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    if (currentForumUserId() == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Masuk untuk ikut membalas.',
                style: textTheme.bodyMedium?.copyWith(color: tk.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/account/login'),
              child: const Text('Masuk'),
            ),
          ],
        ),
      );
    }
    final me = ref.watch(myForumProfileProvider).asData?.value;
    final name = me == null
        ? 'Kamu'
        : (me.displayName?.trim().isNotEmpty ?? false)
        ? me.displayName!
        : (me.username ?? 'Kamu');
    final length = controller.text.length;
    final canSend = !submitting && controller.text.trim().isNotEmpty;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(TkRadius.control),
      borderSide: BorderSide.none,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: MentionSuggestions(controller: controller),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TkAvatar(name: name, imageUrl: me?.avatarUrl, size: 32),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(_maxReplyLength),
                  ],
                  decoration: InputDecoration(
                    hintText: 'Balas postingan ini',
                    fillColor: tk.surfaceAlt,
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: fieldBorder,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    counterText: length >= 800
                        ? '${_maxReplyLength - length}'
                        : null,
                    counterStyle: textTheme.labelMedium?.copyWith(
                      color: _maxReplyLength - length <= 100
                          ? tk.danger
                          : tk.textMuted,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 0),
                child: submitting
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Kirim balasan',
                        onPressed: canSend ? onSend : null,
                        icon: Icon(
                          Icons.send_rounded,
                          color: canSend ? tk.primary : tk.textMuted,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One reply: avatar in a 48dp column (centered under the post's avatar so
/// the thread line lands on it), name, @username and time on one line, the
/// text with mentions, and an overflow menu (edit/delete for your own,
/// report/block for others').
class _ReplyTile extends ConsumerStatefulWidget {
  const _ReplyTile({required this.comment, required this.postId, super.key});

  final ForumComment comment;
  final String postId;

  @override
  ConsumerState<_ReplyTile> createState() => _ReplyTileState();
}

class _ReplyTileState extends ConsumerState<_ReplyTile> {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ref.invalidate(forumCommentsProvider(widget.postId));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus balasan?'),
        content: const Text('Balasan yang dihapus tidak bisa dikembalikan.'),
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
    await ref
        .read(forumControllerProvider.notifier)
        .deleteComment(widget.comment.id);
    ref
      ..invalidate(forumCommentsProvider(widget.postId))
      ..invalidate(forumPostProvider(widget.postId));
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final comment = widget.comment;
    final label = forumAuthorLabel(comment.author);
    final isOwner = currentForumUserId() == comment.userId;
    void openProfile() => context.push('/social/user/${comment.userId}');

    final menu = PopupMenuButton<String>(
      tooltip: 'Opsi balasan',
      icon: Icon(Icons.more_horiz_rounded, size: 20, color: tk.textMuted),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            setState(() {
              _editController.text = comment.body;
              _isEditing = true;
            });
          case 'delete':
            unawaited(_confirmDelete());
          case 'report':
            unawaited(reportForumContent(context, ref, commentId: comment.id));
          case 'block':
            unawaited(
              blockForumUser(
                context,
                ref,
                userId: comment.userId,
                displayName: label.name,
              ),
            );
        }
      },
      itemBuilder: (context) => isOwner
          ? <PopupMenuEntry<String>>[
              forumMenuItem(
                context,
                value: 'edit',
                icon: Icons.edit_outlined,
                label: 'Edit balasan',
              ),
              forumMenuItem(
                context,
                value: 'delete',
                icon: Icons.delete_outline_rounded,
                label: 'Hapus balasan',
                destructive: true,
              ),
            ]
          : forumModerationMenuItems(context),
    );

    return Stack(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                button: true,
                label: 'Buka profil ${label.name}',
                excludeSemantics: true,
                child: InkResponse(
                  onTap: openProfile,
                  radius: 24,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: TkAvatar(
                        name: label.name,
                        imageUrl: comment.author?.avatarUrl,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(right: 36, top: 2),
                      child: ForumByline(
                        name: label.name,
                        handle: label.handle,
                        time: comment.createdAt,
                        onTap: openProfile,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (_isEditing) ...<Widget>[
                      TextField(
                        controller: _editController,
                        maxLines: null,
                        autofocus: true,
                        inputFormatters: <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(_maxReplyLength),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Simpan'),
                          ),
                        ],
                      ),
                    ] else
                      MentionText(comment.body),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!_isEditing) Positioned(top: 2, right: 4, child: menu),
      ],
    );
  }
}
