import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/presentation/account_controller.dart';

Future<void> showEditDisplayNameDialog(
  BuildContext context,
  WidgetRef ref, {
  String? currentName,
}) async {
  final controller = TextEditingController(text: currentName ?? '');
  final formKey = GlobalKey<FormState>();
  String? error;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('Ubah nama'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nama tampilan'),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Nama tidak boleh kosong.';
                  if (trimmed.length > 80) return 'Nama maksimal 80 karakter.';
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
                      .updateDisplayName(controller.text.trim());
                  if (result != null) {
                    setState(() => error = result);
                    return;
                  }
                  ref.invalidate(userDisplayNameProvider);
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
