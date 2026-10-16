import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import 'forum_controller.dart';
import 'forum_session.dart';
import 'widgets/forum_line_chip.dart';
import 'widgets/mentions.dart';

const forumMaxBodyLength = 2000;

/// Full-screen compose view: Batal and Kirim in the top bar, the author's
/// avatar beside a large multiline field, an optional photo, a line tag, and
/// a toolbar with the character counter. Leaving with text or a photo asks
/// before discarding.
class ForumPostComposerPage extends ConsumerStatefulWidget {
  const ForumPostComposerPage({super.key});

  @override
  ConsumerState<ForumPostComposerPage> createState() =>
      _ForumPostComposerPageState();
}

class _ForumPostComposerPageState extends ConsumerState<ForumPostComposerPage> {
  final _bodyController = TextEditingController();
  Uint8List? _imageBytes;
  String? _lineId;
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
      _bodyController.text.trim().isNotEmpty || _imageBytes != null;

  bool get _canSend => !_submitting && _bodyController.text.trim().isNotEmpty;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _imageBytes = bytes);
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

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await ref
        .read(forumControllerProvider.notifier)
        .createPost(body, imageBytes: _imageBytes, lineId: _lineId);
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
    final length = _bodyController.text.length;
    final remaining = forumMaxBodyLength - length;
    final name = me == null
        ? 'Kamu'
        : (me.displayName?.trim().isNotEmpty ?? false)
        ? me.displayName!
        : (me.username ?? 'Kamu');

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
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onPressed: signedIn && _canSend ? _submit : null,
                  child: _submitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: tk.onPrimary,
                          ),
                        )
                      : const Text('Kirim'),
                ),
              ),
            ),
          ],
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
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            TkAvatar(
                              name: name,
                              imageUrl: me?.avatarUrl,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.titleSmall,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _bodyController,
                                    autofocus: true,
                                    minLines: 6,
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
                                    decoration: InputDecoration.collapsed(
                                      hintText: 'Apa yang terjadi di jalurmu?',
                                      hintStyle: textTheme.bodyLarge?.copyWith(
                                        color: tk.textMuted,
                                      ),
                                    ),
                                  ),
                                  if (_imageBytes != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: _ImagePreview(
                                        bytes: _imageBytes!,
                                        onRemove: () =>
                                            setState(() => _imageBytes = null),
                                      ),
                                    ),
                                  if (_error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
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
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: tk.danger,
                                          ),
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
                    MentionSuggestions(controller: _bodyController),
                    if (lines != null && lines.isNotEmpty)
                      SizedBox(
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: lines.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 4),
                          itemBuilder: (context, index) {
                            final line = lines[index];
                            final selected = _lineId == line.id;
                            return ForumLineChip(
                              label: line.code,
                              semanticLabel: 'Tandai jalur ${line.name}',
                              color: line.resolvedColor,
                              selected: selected,
                              onTap: () => setState(
                                () => _lineId = selected ? null : line.id,
                              ),
                            );
                          },
                        ),
                      ),
                    Divider(height: 1, color: tk.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: <Widget>[
                          IconButton(
                            tooltip: 'Tambah foto',
                            icon: const Icon(Icons.image_outlined),
                            onPressed: _submitting ? null : _pickImage,
                          ),
                          IconButton(
                            tooltip: 'Tandai pengguna',
                            icon: const Icon(Icons.alternate_email_rounded),
                            onPressed: _submitting
                                ? null
                                : _insertMentionTrigger,
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text(
                              '$length / $forumMaxBodyLength',
                              style: textTheme.labelMedium?.copyWith(
                                color: remaining <= 100
                                    ? tk.danger
                                    : tk.textMuted,
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
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(TkRadius.control),
          child: Image.memory(
            bytes,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            semanticLabel: 'Foto yang akan diposting',
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: IconButton.filled(
            tooltip: 'Hapus foto',
            style: IconButton.styleFrom(
              backgroundColor: tk.surface,
              foregroundColor: tk.text,
            ),
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }
}
