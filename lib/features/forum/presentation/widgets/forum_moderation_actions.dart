import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../forum_controller.dart';

const _reportReasons = <(String, String)>[
  ('spam', 'Spam atau iklan'),
  ('harassment', 'Pelecehan atau ujaran kebencian'),
  ('inappropriate', 'Konten tidak pantas'),
  ('misinformation', 'Informasi menyesatkan'),
  ('other', 'Lainnya'),
];

/// Asks why, then files a report against a post (pass [postId]) or a comment
/// (pass [commentId]) and confirms with a snackbar.
Future<void> reportForumContent(
  BuildContext context,
  WidgetRef ref, {
  String? postId,
  String? commentId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(forumControllerProvider.notifier);
  final reason = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              commentId != null ? 'Laporkan balasan' : 'Laporkan postingan',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          for (final (value, label) in _reportReasons)
            InkWell(
              onTap: () => Navigator.of(sheetContext).pop(value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: Theme.of(sheetContext).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (reason == null) return;
  final error = await controller.reportContent(
    postId: postId,
    commentId: commentId,
    reason: reason,
  );
  messenger.showSnackBar(
    SnackBar(
      content: Text(error ?? 'Laporan terkirim. Tim kami akan meninjaunya.'),
    ),
  );
}

/// Confirms, then blocks [userId]. [displayName] is only used in the dialog.
/// Returns true when the user ended up blocked.
Future<bool> blockForumUser(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String displayName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(forumControllerProvider.notifier);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Blokir $displayName?'),
      content: const Text(
        'Postingan dan balasan pengguna ini tidak akan muncul lagi di '
        'forummu. Kamu bisa membuka blokir lewat bagian Sosial di Profil.',
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
          child: const Text('Blokir'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  final error = await controller.blockUser(userId);
  messenger.showSnackBar(
    SnackBar(content: Text(error ?? '$displayName diblokir.')),
  );
  return error == null;
}

/// One row of a post/reply overflow menu: icon + label, danger-tinted when
/// [destructive].
PopupMenuItem<String> forumMenuItem(
  BuildContext context, {
  required String value,
  required IconData icon,
  required String label,
  bool destructive = false,
}) {
  final tk = context.tk;
  final color = destructive ? tk.danger : tk.text;
  return PopupMenuItem<String>(
    value: value,
    height: 48,
    child: Row(
      children: <Widget>[
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

/// Menu entries shared by the post and reply overflow menus for content
/// written by someone else: 'report' and 'block'.
List<PopupMenuEntry<String>> forumModerationMenuItems(BuildContext context) =>
    <PopupMenuEntry<String>>[
      forumMenuItem(
        context,
        value: 'report',
        icon: Icons.flag_outlined,
        label: 'Laporkan',
      ),
      forumMenuItem(
        context,
        value: 'block',
        icon: Icons.block_rounded,
        label: 'Blokir pengguna',
        destructive: true,
      ),
    ];
