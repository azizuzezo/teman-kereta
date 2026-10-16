import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'account_controller.dart';

/// Two-step confirmation (explain, then type "HAPUS") before permanently
/// deleting the signed-in account. On success sends the user back to the
/// home screen as a guest.
Future<void> confirmAndDeleteAccount(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
  if (confirmed != true) return;

  messenger.showSnackBar(
    const SnackBar(
      content: Text('Menghapus akun…'),
      duration: Duration(seconds: 30),
    ),
  );
  final error = await ref
      .read(accountControllerProvider.notifier)
      .deleteAccount();
  messenger.hideCurrentSnackBar();
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
    return;
  }
  messenger.showSnackBar(
    const SnackBar(content: Text('Akunmu dan datanya sudah dihapus.')),
  );
  router.go('/');
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hapus akun secara permanen?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Ini akan menghapus akunmu beserta semua datanya di server: '
              'profil, foto profil, rute favorit, preferensi, daftar pengikut, '
              'serta semua postingan, komentar, dan foto forummu. '
              'Tindakan ini tidak dapat dibatalkan.\n\n'
              'Riwayat perjalanan yang tersimpan di perangkat ini tidak ikut terhapus.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Ketik HAPUS untuk melanjutkan',
              ),
              onChanged: (value) {
                final matches = value.trim().toUpperCase() == 'HAPUS';
                if (matches != _matches) setState(() => _matches = matches);
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Hapus akun'),
        ),
      ],
    );
  }
}
