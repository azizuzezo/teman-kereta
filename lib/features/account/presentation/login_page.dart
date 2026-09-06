import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../settings/presentation/edit_display_name_dialog.dart' show kMaxDisplayNameLength;
import 'account_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isSubmitting = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
      _info = null;
    });

    final controller = ref.read(accountControllerProvider.notifier);
    if (_isSignUp) {
      final result = await controller.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = result.error;
        if (result.error == null) {
          _info = result.needsEmailConfirmation
              ? 'Akun berhasil dibuat! Silakan periksa email Anda (termasuk folder Spam) untuk mengonfirmasi akun sebelum masuk.'
              : 'Akun berhasil dibuat.';
          _isSignUp = false;
        }
      });
      if (result.error == null && !result.needsEmailConfirmation) {
        // A brand-new account's `public.users.username` is null until the
        // user picks one — force that before letting them into the app
        // (unlike a normal sign-in of an existing account, below).
        final username = await ref
            .read(accountControllerProvider.notifier)
            .fetchUsername();
        if (!mounted) return;
        if (username == null || username.isEmpty) {
          unawaited(context.push('/account/set-username'));
        } else {
          _closeOrGoHome();
        }
      }
      return;
    }

    final error = await controller.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _error = error;
    });
    if (error == null) {
      _closeOrGoHome();
    }
  }

  /// Pops back to whatever pushed the login page (e.g. an in-app "Masuk"
  /// prompt), or — when there is nothing to pop to, because the mandatory
  /// login-gate redirect (see `app_router.dart`) put the user here directly
  /// — navigates to home instead.
  void _closeOrGoHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(
        emailController: emailCtrl,
        onSend: (email) async {
          final controller = ref.read(accountControllerProvider.notifier);
          return controller.resetPassword(email: email);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Buat akun' : 'Masuk')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _isSignUp
                      ? 'Buat akun untuk menyinkronkan preferensi dan nama profil Anda.'
                      : 'Masuk ke akunmu untuk melanjutkan.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (_isSignUp) ...<Widget>[
                  TextFormField(
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    // Same cap as "Ubah nama" in Profil — a name set at
                    // sign-up is the same field, so it can't be allowed in
                    // longer here than the editor will later accept.
                    maxLength: kMaxDisplayNameLength,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      hintText: 'Masukkan nama Anda',
                      helperText: 'Maksimal $kMaxDisplayNameLength karakter.',
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Nama lengkap wajib diisi.';
                      }
                      if (trimmed.length > kMaxDisplayNameLength) {
                        return 'Nama maksimal $kMaxDisplayNameLength karakter.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const <String>[AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Masukkan email yang valid.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const <String>[AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Kata sandi'),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Kata sandi minimal 6 karakter.';
                    }
                    return null;
                  },
                ),
                // Forgot password link — only shown on login mode
                if (!_isSignUp) ...<Widget>[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _showForgotPasswordDialog,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Lupa kata sandi?'),
                    ),
                  ),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (_info != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _info!,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
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
                        : Text(_isSignUp ? 'Daftar' : 'Masuk'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                          _isSignUp = !_isSignUp;
                          _error = null;
                          _info = null;
                        }),
                  child: Text(
                    _isSignUp
                        ? 'Sudah punya akun? Masuk'
                        : 'Belum punya akun? Daftar',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog untuk mengirim link reset password ke email pengguna.
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.emailController,
    required this.onSend,
  });

  final TextEditingController emailController;
  final Future<String?> Function(String email) onSend;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;
  String? _error;
  bool _sent = false;

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSending = true;
      _error = null;
    });
    final error = await widget.onSend(widget.emailController.text.trim());
    if (!mounted) return;
    if (error == null) {
      setState(() {
        _isSending = false;
        _sent = true;
      });
    } else {
      setState(() {
        _isSending = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lupa Kata Sandi?'),
      content: _sent
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.mark_email_read_rounded,
                  size: 48,
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                Text(
                  'Link reset kata sandi telah dikirim ke ${widget.emailController.text.trim()}.\n\nSilakan periksa inbox atau folder Spam Anda.',
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Masukkan email akun Anda. Kami akan mengirimkan link untuk mereset kata sandi.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: widget.emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || !value.contains('@')) {
                        return 'Masukkan email yang valid.';
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
      actions: _sent
          ? <Widget>[
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
            ]
          : <Widget>[
              TextButton(
                onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: _isSending ? null : _send,
                child: _isSending
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kirim Link Reset'),
              ),
            ],
    );
  }
}
