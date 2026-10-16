import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/app_theme.dart';
import 'auth_errors.dart';
import 'widgets/auth_notice.dart';
import 'widgets/password_field.dart';

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
  final _confirmFocus = FocusNode();
  bool _isSubmitting = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
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
    } on Object catch (error) {
      if (!mounted) return;
      final failure = mapAuthError(error, AuthFlow.resetPassword);
      setState(() {
        _isSubmitting = false;
        // The reset flow has its own wording for a failed update; keep the
        // specific cases (offline, weak password) from the shared mapper.
        _error =
            failure.offline ||
                failure.rateLimited ||
                error is AuthWeakPasswordException
            ? failure.message
            : 'Gagal memperbarui kata sandi. Link reset mungkin sudah kedaluwarsa, minta link baru dari halaman masuk.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kata sandi baru')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _done
                  ? const _SuccessView()
                  : _FormView(
                      formKey: _formKey,
                      passwordController: _passwordController,
                      confirmController: _confirmController,
                      confirmFocus: _confirmFocus,
                      isSubmitting: _isSubmitting,
                      error: _error,
                      onSubmit: () => unawaited(_submit()),
                    ),
            ),
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
    required this.confirmFocus,
    required this.isSubmitting,
    required this.error,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final FocusNode confirmFocus;
  final bool isSubmitting;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tk.primarySoft,
                  borderRadius: BorderRadius.circular(TkRadius.card),
                ),
                child: Icon(
                  Icons.lock_reset_rounded,
                  size: 32,
                  color: tk.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Buat kata sandi baru',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: tk.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih kata sandi baru untuk akunmu, minimal $kMinPasswordLength karakter.',
              style: theme.textTheme.bodyMedium?.copyWith(color: tk.textMuted),
            ),
            const SizedBox(height: 24),
            Text(
              'Kata sandi baru',
              style: theme.textTheme.labelLarge?.copyWith(
                color: tk.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            PasswordField(
              controller: passwordController,
              enabled: !isSubmitting,
              hintText: 'Minimal $kMinPasswordLength karakter',
              autofillHints: const <String>[AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUnfocus,
              onFieldSubmitted: (_) => confirmFocus.requestFocus(),
              validator: validateNewPassword,
            ),
            const SizedBox(height: 16),
            Text(
              'Ulangi kata sandi baru',
              style: theme.textTheme.labelLarge?.copyWith(
                color: tk.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            PasswordField(
              controller: confirmController,
              focusNode: confirmFocus,
              enabled: !isSubmitting,
              hintText: 'Ketik ulang kata sandi',
              autofillHints: const <String>[AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              autovalidateMode: AutovalidateMode.onUnfocus,
              onFieldSubmitted: (_) => onSubmit(),
              validator: (value) =>
                  validatePasswordMatch(value, passwordController.text),
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: 16),
              AuthNotice(message: error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isSubmitting ? null : onSubmit,
              child: isSubmitting
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: tk.onPrimary,
                        semanticsLabel: 'Menyimpan',
                      ),
                    )
                  : const Text('Simpan kata sandi baru'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: tk.successSoft,
              borderRadius: BorderRadius.circular(TkRadius.card),
            ),
            child: Icon(Icons.check_rounded, size: 40, color: tk.success),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Kata sandi sudah diganti',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: tk.text,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Mulai sekarang masuk pakai kata sandi yang baru.',
          style: theme.textTheme.bodyMedium?.copyWith(color: tk.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Ke beranda'),
        ),
      ],
    );
  }
}
