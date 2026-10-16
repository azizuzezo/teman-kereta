import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../core/widgets/tk_logo.dart';
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
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
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const TkLogo(size: 56, showLabel: false),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      'Pilih username',
                      style: textTheme.headlineLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Satu langkah lagi. Username ini dilihat orang lain di '
                    'forum dan daftar pengikut.',
                    style: textTheme.bodyLarge?.copyWith(color: tk.textMuted),
                  ),
                  const SizedBox(height: 16),
                  TkCard(
                    tone: TkCardTone.warning,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.lock_outline_rounded, color: tk.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Username tidak bisa diubah lagi setelah disimpan.',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
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
                      if (trimmed.isEmpty) {
                        return 'Username tidak boleh kosong.';
                      }
                      if (!_usernamePattern.hasMatch(trimmed)) {
                        return 'Gunakan 3-10 huruf kecil, angka, atau garis bawah.';
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: textTheme.bodyMedium?.copyWith(color: tk.danger),
                      ),
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
