import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isSubmitting = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
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
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = result.error;
        if (result.error == null) {
          _info = result.needsEmailConfirmation
              ? 'Akun dibuat. Cek emailmu untuk konfirmasi sebelum masuk.'
              : 'Akun dibuat.';
          _isSignUp = false;
        }
      });
      if (result.error == null && !result.needsEmailConfirmation) {
        if (mounted) Navigator.of(context).pop();
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
      Navigator.of(context).pop();
    }
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
                      ? 'Buat akun untuk menyinkronkan preferensimu di perangkat lain nanti.'
                      : 'Masuk ke akunmu. Akun bersifat opsional — aplikasi tetap berfungsi penuh tanpa akun.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
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
