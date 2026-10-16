import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import 'forum_controller.dart';
import 'widgets/forum_skeletons.dart';

/// Lists the users the signed-in account has blocked in the forum, each with
/// an "unblock" action.
class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);
    final tk = context.tk;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengguna yang diblokir')),
      body: SafeArea(
        child: blocked.when(
          loading: () => const SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            child: UserRowSkeleton(count: 4),
          ),
          error: (error, stack) => TkErrorState(
            title: 'Daftar blokir gagal dimuat',
            message: 'Periksa koneksimu, lalu coba lagi.',
            onRetry: () => ref.invalidate(blockedUsersProvider),
          ),
          data: (users) {
            if (users.isEmpty) {
              return const AppEmptyState(
                icon: Icons.block_rounded,
                title: 'Belum ada yang diblokir',
                message:
                    'Pengguna yang kamu blokir dari forum akan muncul di sini.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(blockedUsersProvider);
                try {
                  await ref.read(blockedUsersProvider.future);
                } on Object {
                  // The list shows its own error state.
                }
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: users.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, indent: 72, color: tk.border),
                itemBuilder: (context, index) => _BlockedRow(
                  key: ValueKey<String>(users[index].id),
                  user: users[index],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BlockedRow extends ConsumerStatefulWidget {
  const _BlockedRow({required this.user, super.key});

  final BlockedUser user;

  @override
  ConsumerState<_BlockedRow> createState() => _BlockedRowState();
}

class _BlockedRowState extends ConsumerState<_BlockedRow> {
  bool _busy = false;

  Future<void> _unblock() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final error = await ref
        .read(forumControllerProvider.notifier)
        .unblockUser(widget.user.id);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? '${widget.user.name} tidak diblokir lagi.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            TkAvatar(name: user.name.replaceFirst('@', '')),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(88, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: _busy ? null : _unblock,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Buka blokir'),
            ),
          ],
        ),
      ),
    );
  }
}
