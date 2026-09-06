import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'account_controller.dart';

final _usernamePattern = RegExp(r'^[a-z0-9_]{3,10}$');

/// Forced immediately after a brand-new sign-up whose `public.users` row
/// (auto-created by the `handle_new_auth_user` trigger) still has a null
/// `username` — see `app_router.dart`'s login-required redirect, which
/// exempts this route the same way it exempts `/account/login`, and
/// `login_page.dart`, which pushes here instead of going straight to `/`.
///
/// Deliberately non-dismissible: no "Batal" button, no back navigation, and
/// no way to tap outside to close it. `updateUsername` is a one-way door —
/// once set, `20260822110000_username_immutable.sql`'s DB trigger rejects
/// any further change — so this page's only exit is a successful save.
class SetUsernamePage extends ConsumerStatefulWidget {
  const SetUsernamePage({super.key});

  @override
  ConsumerState<SetUsernamePage> createState() => _SetUsernamePageState();
}

class _SetUsernamePageState extends ConsumerState<SetUsernamePage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final result = await ref
        .read(accountControllerProvider.notifier)
        .updateUsername(_controller.text.trim().toLowerCase());
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _isSubmitting = false;
        _error = result;
      });
      return;
    }
    ref.invalidate(userUsernameProvider);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Atur username'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Satu langkah lagi! Pilih username unik untuk akunmu. '
                    'Username tidak bisa diubah lagi setelah disimpan.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _controller,
                    autofocus: true,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixText: '@',
                      helperText:
                          '3-10 karakter: huruf kecil, angka, garis bawah.',
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
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
