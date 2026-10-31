import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import 'forum_controller.dart';
import 'forum_media.dart';
import 'forum_models.dart';
import 'forum_session.dart';
import 'widgets/forum_line_chip.dart';
import 'widgets/mentions.dart';

const forumMaxBodyLength = 2000;

/// Full-screen compose view in the Threads "new thread" layout: the author's
/// avatar with a thread line beside "name › jalur", a borderless text field,
/// up to four photos/videos (each photo framed 4:3 or at its own shape), the
/// attach and mention buttons, and Posting at the bottom right. Leaving with
/// text or media asks before discarding.
class ForumPostComposerPage extends ConsumerStatefulWidget {
  const ForumPostComposerPage({super.key});

  @override
  ConsumerState<ForumPostComposerPage> createState() =>
      _ForumPostComposerPageState();
}

class _ForumPostComposerPageState extends ConsumerState<ForumPostComposerPage> {
  final _bodyController = TextEditingController();
  final _media = <ForumMediaDraft>[];
  String? _lineId;
  bool _picking = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bodyController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _bodyController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool get _dirty =>
      _bodyController.text.trim().isNotEmpty || _media.isNotEmpty;

  bool get _canSend => !_submitting && _bodyController.text.trim().isNotEmpty;

  Future<void> _pickMedia() async {
    final room = forumMaxMedia - _media.length;
    if (room <= 0) {
      setState(() => _error = 'Maksimal $forumMaxMedia foto atau video.');
      return;
    }
    setState(() => _picking = true);
    final picked = await ImagePicker().pickMultipleMedia(
      imageQuality: 80,
      maxWidth: 1600,
      limit: room,
    );
    final added = <ForumMediaDraft>[];
    final rejected = <String>{};
    for (final file in picked.take(room)) {
      try {
        added.add(await readForumMediaDraft(file));
      } on ForumMediaRejection catch (rejection) {
        rejected.add(rejection.message);
      } on Object {
        rejected.add('Ada file yang tidak bisa dibuka.');
      }
    }
    if (!mounted) return;
    setState(() {
      _picking = false;
      _media.addAll(added);
      _error = rejected.isEmpty
          ? (picked.length > room
                ? 'Maksimal $forumMaxMedia foto atau video.'
                : null)
          : rejected.join(' ');
    });
  }

  void _insertMentionTrigger() {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final at = selection.isValid ? selection.baseOffset : text.length;
    final needsSpace = at > 0 && !RegExp(r'\s').hasMatch(text[at - 1]);
    final insert = needsSpace ? ' @' : '@';
    if (text.length + insert.length > forumMaxBodyLength) return;
    _bodyController.value = TextEditingValue(
      text: text.replaceRange(at, at, insert),
      selection: TextSelection.collapsed(offset: at + insert.length),
    );
  }

  Future<void> _pickLine(List<LineOption> lines) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Tandai jalur',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  ForumLineChip(
                    label: 'Tanpa jalur',
                    selected: _lineId == null,
                    onTap: () => Navigator.of(sheetContext).pop(''),
                  ),
                  for (final line in lines)
                    ForumLineChip(
                      label: line.code,
                      semanticLabel: 'Tandai jalur ${line.name}',
                      color: line.resolvedColor,
                      selected: _lineId == line.id,
                      onTap: () => Navigator.of(sheetContext).pop(line.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _lineId = picked.isEmpty ? null : picked);
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await ref
        .read(forumControllerProvider.notifier)
        .createPost(body, media: List.of(_media), lineId: _lineId);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buang postingan?'),
        content: const Text('Tulisan yang belum terkirim akan hilang.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Lanjut menulis'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.tk.danger,
              foregroundColor: dialogContext.tk.onAccent,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
    // A direct pop is not blocked by PopScope.
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final signedIn = currentForumUserId() != null;
    final me = ref.watch(myForumProfileProvider).asData?.value;
    final lines = ref.watch(forumLineOptionsProvider).asData?.value;
    final line = lines?.where((option) => option.id == _lineId).firstOrNull;
    final length = _bodyController.text.length;
    final remaining = forumMaxBodyLength - length;
    final name = me == null
        ? 'Kamu'
        : (me.displayName?.trim().isNotEmpty ?? false)
        ? me.displayName!
        : (me.username ?? 'Kamu');
    final busy = _submitting || _picking;

    return PopScope(
      canPop: !_dirty || _submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmDiscard());
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 96,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () => unawaited(Navigator.of(context).maybePop()),
                child: const Text('Batal'),
              ),
            ),
          ),
          title: Text('Postingan baru', style: textTheme.titleMedium),
          centerTitle: true,
        ),
        body: SafeArea(
          child: !signedIn
              ? AppEmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Masuk untuk menulis',
                  message: 'Postingan terhubung ke akunmu.',
                  action: FilledButton(
                    onPressed: () => context.push('/account/login'),
                    child: const Text('Masuk'),
                  ),
                )
              : Column(
                  children: <Widget>[
                    Divider(height: 1, color: tk.border),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 14, 0, 16),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Column(
                                children: <Widget>[
                                  TkAvatar(
                                    name: name,
                                    imageUrl: me?.avatarUrl,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      decoration: BoxDecoration(
                                        color: tk.border,
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _AuthorTopicRow(
                                      name: name,
                                      line: line,
                                      onPickLine:
                                          lines == null ||
                                              lines.isEmpty ||
                                              busy
                                          ? null
                                          : () => unawaited(_pickLine(lines)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: TextField(
                                        controller: _bodyController,
                                        autofocus: true,
                                        minLines: 2,
                                        maxLines: null,
                                        keyboardType: TextInputType.multiline,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        inputFormatters: <TextInputFormatter>[
                                          LengthLimitingTextInputFormatter(
                                            forumMaxBodyLength,
                                          ),
                                        ],
                                        style: textTheme.bodyLarge,
                                        // Borderless like Threads. Every
                                        // border is set explicitly: the
                                        // theme's rounded focus border would
                                        // otherwise sit right on the text.
                                        decoration: InputDecoration(
                                          hintText:
                                              'Apa yang terjadi di jalurmu?',
                                          hintStyle: textTheme.bodyLarge
                                              ?.copyWith(color: tk.textMuted),
                                          filled: false,
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 6,
                                              ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    if (_media.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: _DraftStrip(
                                          drafts: _media,
                                          onRemove: (draft) => setState(
                                            () => _media.remove(draft),
                                          ),
                                          onToggleFit: (draft) => setState(
                                            () => draft.fit =
                                                draft.fit ==
                                                    ForumMediaFit.original
                                                ? ForumMediaFit.fourByThree
                                                : ForumMediaFit.original,
                                          ),
                                        ),
                                      ),
                                    Transform.translate(
                                      offset: const Offset(-12, 0),
                                      child: Row(
                                        children: <Widget>[
                                          IconButton(
                                            tooltip: 'Tambah foto atau video',
                                            icon: _picking
                                                ? const SizedBox.square(
                                                    dimension: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : Icon(
                                                    Icons
                                                        .photo_library_outlined,
                                                    color: tk.textMuted,
                                                  ),
                                            onPressed:
                                                busy ||
                                                    _media.length >=
                                                        forumMaxMedia
                                                ? null
                                                : () => unawaited(
                                                    _pickMedia(),
                                                  ),
                                          ),
                                          IconButton(
                                            tooltip: 'Tandai pengguna',
                                            icon: Icon(
                                              Icons.alternate_email_rounded,
                                              color: tk.textMuted,
                                            ),
                                            onPressed: _submitting
                                                ? null
                                                : _insertMentionTrigger,
                                          ),
                                          if (_media.isNotEmpty)
                                            Text(
                                              '${_media.length}/$forumMaxMedia',
                                              style: textTheme.labelMedium
                                                  ?.copyWith(
                                                    color: tk.textMuted,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (_error != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                          right: 16,
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: tk.dangerSoft,
                                            borderRadius: BorderRadius.circular(
                                              TkRadius.control,
                                            ),
                                          ),
                                          child: Text(
                                            _error!,
                                            style: textTheme.bodyMedium
                                                ?.copyWith(color: tk.danger),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    MentionSuggestions(controller: _bodyController),
                    Divider(height: 1, color: tk.border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '$length / $forumMaxBodyLength',
                              style: textTheme.labelMedium?.copyWith(
                                color: remaining <= 100
                                    ? tk.danger
                                    : tk.textMuted,
                              ),
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(88, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                            ),
                            onPressed: _canSend && !_picking ? _submit : null,
                            child: _submitting
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: tk.onPrimary,
                                    ),
                                  )
                                : const Text('Posting'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// "Name › Pilih jalur" — tapping the topic opens the line picker.
class _AuthorTopicRow extends StatelessWidget {
  const _AuthorTopicRow({
    required this.name,
    required this.line,
    required this.onPickLine,
  });

  final String name;
  final LineOption? line;
  final VoidCallback? onPickLine;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final picked = line;
    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall,
          ),
        ),
        Icon(Icons.chevron_right_rounded, size: 18, color: tk.textMuted),
        Flexible(
          child: Semantics(
            button: true,
            label: picked == null
                ? 'Pilih jalur'
                : 'Jalur ${picked.name}. Ketuk untuk mengganti.',
            excludeSemantics: true,
            child: InkWell(
              onTap: onPickLine,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                child: Text(
                  picked?.name ?? 'Pilih jalur',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: picked == null
                      ? textTheme.bodyMedium?.copyWith(color: tk.textMuted)
                      : textTheme.titleSmall?.copyWith(
                          color: picked.resolvedColor,
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The picked photos/videos, each at the shape it will be posted with.
class _DraftStrip extends StatelessWidget {
  const _DraftStrip({
    required this.drafts,
    required this.onRemove,
    required this.onToggleFit,
  });

  final List<ForumMediaDraft> drafts;
  final ValueChanged<ForumMediaDraft> onRemove;
  final ValueChanged<ForumMediaDraft> onToggleFit;

  static const _height = 200.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 16),
        itemCount: drafts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final draft = drafts[index];
          return _DraftTile(
            key: ObjectKey(draft),
            draft: draft,
            width: _height * draft.aspectRatio.clamp(0.6, 1.6),
            height: _height,
            onRemove: () => onRemove(draft),
            onToggleFit: () => onToggleFit(draft),
          );
        },
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.draft,
    required this.width,
    required this.height,
    required this.onRemove,
    required this.onToggleFit,
    super.key,
  });

  final ForumMediaDraft draft;
  final double width;
  final double height;
  final VoidCallback onRemove;
  final VoidCallback onToggleFit;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tk.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tk.border, width: 0.5),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (draft.isVideo)
            _DraftVideoFrame(path: draft.file.path)
          else
            Image.file(
              File(draft.file.path),
              fit: BoxFit.cover,
              semanticLabel: 'Foto yang akan diposting',
            ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton.filled(
              tooltip: draft.isVideo ? 'Hapus video' : 'Hapus foto',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: draft.isVideo
                ? _TileLabel(
                    icon: Icons.videocam_rounded,
                    text: formatVideoDuration(draft.duration ?? Duration.zero),
                  )
                : Semantics(
                    button: true,
                    label: draft.fit == ForumMediaFit.fourByThree
                        ? 'Bingkai 4:3. Ketuk untuk ukuran asli.'
                        : 'Ukuran asli. Ketuk untuk bingkai 4:3.',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: onToggleFit,
                      child: _TileLabel(
                        icon: Icons.crop_rounded,
                        text: draft.fit == ForumMediaFit.fourByThree
                            ? '4:3'
                            : 'Asli',
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TileLabel extends StatelessWidget {
  const _TileLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// First frame of a picked video, for its preview tile.
class _DraftVideoFrame extends StatefulWidget {
  const _DraftVideoFrame({required this.path});

  final String path;

  @override
  State<_DraftVideoFrame> createState() => _DraftVideoFrameState();
}

class _DraftVideoFrameState extends State<_DraftVideoFrame> {
  late final VideoPlayerController _controller = VideoPlayerController.file(
    File(widget.path),
  );
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      _controller
          .initialize()
          .then((_) {
            if (mounted) setState(() => _ready = true);
          })
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
