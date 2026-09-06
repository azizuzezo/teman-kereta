import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Halaman set password baru setelah user klik link reset dari email.
/// Dipanggil melalui deep link: temankereta://app/account/reset-password
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _done = true;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'Gagal memperbarui kata sandi. Silakan coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Kata Sandi Baru')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _done ? _SuccessView() : _FormView(
            formKey: _formKey,
            passwordController: _passwordController,
            confirmController: _confirmController,
            isSubmitting: _isSubmitting,
            error: _error,
            onSubmit: _submit,
          ),
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.formKey,
    required this.passwordController,
    required this.confirmController,
    required this.isSubmitting,
    required this.error,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool isSubmitting;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.lock_reset_rounded, size: 48),
          const SizedBox(height: 16),
          Text(
            'Buat Kata Sandi Baru',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Masukkan kata sandi baru untuk akunmu.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: passwordController,
            obscureText: true,
            autofillHints: const <String>[AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'Kata sandi baru',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Kata sandi minimal 6 karakter.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: confirmController,
            obscureText: true,
            autofillHints: const <String>[AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'Konfirmasi kata sandi',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            validator: (value) {
              if (value != passwordController.text) {
                return 'Kata sandi tidak cocok.';
              }
              return null;
            },
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSubmitting ? null : onSubmit,
              child: isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan Kata Sandi Baru'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const SizedBox(height: 40),
        const Icon(Icons.check_circle_rounded, size: 72, color: Colors.green),
        const SizedBox(height: 20),
        Text(
          'Kata Sandi Berhasil Diubah!',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Kata sandi akunmu sudah diperbarui.\nSilakan masuk kembali menggunakan kata sandi baru.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.login_rounded),
            label: const Text('Masuk Sekarang'),
            onPressed: () => Navigator.of(context)
              ..pop()
              ..pop(),
          ),
        ),
      ],
    );
  }
}
