import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/presentation/account_controller.dart';

final _usernamePattern = RegExp(r'^[a-z0-9_]{3,10}$');

Future<void> showEditUsernameDialog(
  BuildContext context,
  WidgetRef ref, {
  String? currentUsername,
}) async {
  final controller = TextEditingController(text: currentUsername ?? '');
  final formKey = GlobalKey<FormState>();
  String? error;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('Atur username'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixText: '@',
                  helperText: '3-10 karakter: huruf kecil, angka, garis bawah.',
                ),
                validator: (value) {
                  final trimmed = value?.trim().toLowerCase() ?? '';
                  if (trimmed.isEmpty) return 'Username tidak boleh kosong.';
                  if (!_usernamePattern.hasMatch(trimmed)) {
                    return 'Gunakan 3-10 huruf kecil, angka, atau garis bawah.';
                  }
                  return null;
                },
              ),
            ),
            actions: <Widget>[
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  final result = await ref
                      .read(accountControllerProvider.notifier)
                      .updateUsername(controller.text.trim().toLowerCase());
                  if (result != null) {
                    setState(() => error = result);
                    return;
                  }
                  ref.invalidate(userUsernameProvider);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      );
    },
  );
}
