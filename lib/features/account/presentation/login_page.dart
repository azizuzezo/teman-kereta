import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_theme.dart';
import '../../settings/presentation/edit_display_name_dialog.dart'
    show kMaxDisplayNameLength;
import 'account_controller.dart';
import 'auth_errors.dart';
import 'widgets/auth_notice.dart';
import 'widgets/password_field.dart';

final Uri _privacyUrl = Uri.parse('https://temankereta.web.id/privacy');

/// Masuk / Daftar. Sign-up does not finish here: the server emails a 6 digit
/// code and `/account/verify-otp` collects it.
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
  final _confirmController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final Set<FocusNode> _touched = <FocusNode>{};
  late final List<FocusNode> _nodes = <FocusNode>[
    _nameFocus,
    _emailFocus,
    _passwordFocus,
    _confirmFocus,
  ];

  bool _isSignUp = false;
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    for (final node in _nodes) {
      node.addListener(() => _onFocusChange(node));
    }
  }

  void _onFocusChange(FocusNode node) {
    // Inline errors appear once the user leaves a field, not while typing.
    if (!node.hasFocus && mounted && _touched.add(node)) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  AutovalidateMode _validateMode(FocusNode node) =>
      _submitted || _touched.contains(node)
      ? AutovalidateMode.always
      : AutovalidateMode.disabled;

  void _setMode({required bool signUp}) {
    if (_isSignUp == signUp) return;
    setState(() {
      _isSignUp = signUp;
      _error = null;
      _info = null;
      _submitted = false;
      _touched.clear();
    });
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _error = null;
      _info = null;
    });

    final controller = ref.read(accountControllerProvider.notifier);
    final email = _emailController.text.trim();

    if (_isSignUp) {
      final result = await controller.signUp(
        email: email,
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
      if (!mounted) return;
      if (result.alreadyRegistered) {
        // Same address, so keep it and let them sign in instead.
        setState(() {
          _isSubmitting = false;
          _isSignUp = false;
          _submitted = false;
          _touched.clear();
          _info = result.error;
        });
        return;
      }
      setState(() {
        _isSubmitting = false;
        _error = result.error;
      });
      if (result.error != null) return;
      if (result.needsEmailConfirmation) {
        unawaited(_openVerification(email));
        return;
      }
      // Project has email confirmation off: Auth already signed us in.
      await _afterSignedIn(newAccount: true);
      return;
    }

    final result = await controller.signIn(
      email: email,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _error = result.error;
    });
    if (result.needsVerification) {
      unawaited(_openVerification(email, resend: true));
      return;
    }
    if (result.error == null) {
      TextInput.finishAutofillContext();
      await _afterSignedIn(newAccount: false);
    }
  }

  Future<void> _openVerification(String email, {bool resend = false}) {
    final uri = Uri(
      path: '/account/verify-otp',
      queryParameters: <String, String>{
        'email': email,
        if (resend) 'resend': '1',
      },
    );
    return context.push<void>(uri.toString());
  }

  Future<void> _afterSignedIn({required bool newAccount}) async {
    if (newAccount) {
      // A brand-new account's `public.users.username` is null until the
      // user picks one, so force that before letting them into the app.
      final username = await ref
          .read(accountControllerProvider.notifier)
          .fetchUsername();
      if (!mounted) return;
      if (username == null || username.isEmpty) {
        unawaited(context.push('/account/set-username'));
        return;
      }
    }
    _closeOrGoHome();
  }

  /// Pops back to whatever pushed the login page (e.g. an in-app "Masuk"
  /// prompt), or, when there is nothing to pop to because the mandatory
  /// login-gate redirect (see `app_router.dart`) put the user here directly,
  /// navigates to home instead.
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
    emailCtrl.dispose();
  }

  Future<void> _openPrivacy() async {
    var opened = false;
    try {
      opened = await launchUrl(
        _privacyUrl,
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak bisa membuka halaman. Coba lagi nanti.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: tk.bg,
      appBar: canPop ? AppBar(leading: const BackButton()) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(24, canPop ? 0 : 24, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _BrandHeader(),
                      const SizedBox(height: 24),
                      Text(
                        _isSignUp
                            ? 'Buat akun Teman Kereta'
                            : 'Selamat datang kembali',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: tk.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSignUp
                            ? 'Kami kirim kode $kOtpLength digit ke emailmu untuk memastikan akun ini milikmu.'
                            : 'Masuk untuk lanjut ke jadwal, forum, dan perjalananmu.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tk.textMuted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ModeSwitch(
                        isSignUp: _isSignUp,
                        onChanged: _isSubmitting
                            ? null
                            : (value) => _setMode(signUp: value),
                      ),
                      const SizedBox(height: 20),
                      if (_isSignUp) ...<Widget>[
                        _Labeled(
                          label: 'Nama lengkap',
                          child: TextFormField(
                            controller: _nameController,
                            focusNode: _nameFocus,
                            enabled: !_isSubmitting,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[AutofillHints.name],
                            autovalidateMode: _validateMode(_nameFocus),
                            // Same cap as "Ubah nama" in Profil: a name set at
                            // sign-up is the same field.
                            maxLength: kMaxDisplayNameLength,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                            decoration: InputDecoration(
                              hintText: 'Nama yang tampil di profilmu',
                              counterText: '',
                              prefixIcon: Icon(
                                Icons.person_outline_rounded,
                                color: tk.textMuted,
                              ),
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
                        ),
                        const SizedBox(height: 16),
                      ],
                      _Labeled(
                        label: 'Email',
                        child: TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          enabled: !_isSubmitting,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          autofillHints: const <String>[AutofillHints.email],
                          autovalidateMode: _validateMode(_emailFocus),
                          onFieldSubmitted: (_) =>
                              _passwordFocus.requestFocus(),
                          decoration: InputDecoration(
                            hintText: 'nama@email.com',
                            prefixIcon: Icon(
                              Icons.mail_outline_rounded,
                              color: tk.textMuted,
                            ),
                          ),
                          validator: validateEmail,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Labeled(
                        label: 'Kata sandi',
                        child: PasswordField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          enabled: !_isSubmitting,
                          hintText: _isSignUp
                              ? 'Minimal $kMinPasswordLength karakter'
                              : 'Kata sandimu',
                          autofillHints: <String>[
                            _isSignUp
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          textInputAction: _isSignUp
                              ? TextInputAction.next
                              : TextInputAction.done,
                          autovalidateMode: _validateMode(_passwordFocus),
                          onFieldSubmitted: (_) {
                            if (_isSignUp) {
                              _confirmFocus.requestFocus();
                            } else {
                              unawaited(_submit());
                            }
                          },
                          validator: _isSignUp
                              ? validateNewPassword
                              : validateCurrentPassword,
                        ),
                      ),
                      if (_isSignUp) ...<Widget>[
                        const SizedBox(height: 16),
                        _Labeled(
                          label: 'Ulangi kata sandi',
                          child: PasswordField(
                            controller: _confirmController,
                            focusNode: _confirmFocus,
                            enabled: !_isSubmitting,
                            hintText: 'Ketik ulang kata sandi',
                            autofillHints: const <String>[
                              AutofillHints.newPassword,
                            ],
                            textInputAction: TextInputAction.done,
                            autovalidateMode: _validateMode(_confirmFocus),
                            onFieldSubmitted: (_) => unawaited(_submit()),
                            validator: (value) => validatePasswordMatch(
                              value,
                              _passwordController.text,
                            ),
                          ),
                        ),
                      ] else
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isSubmitting
                                ? null
                                : _showForgotPasswordDialog,
                            child: const Text('Lupa kata sandi?'),
                          ),
                        ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 16),
                        AuthNotice(message: _error!),
                      ],
                      if (_info != null) ...<Widget>[
                        const SizedBox(height: 16),
                        AuthNotice(message: _info!, tone: AuthNoticeTone.info),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => unawaited(_submit()),
                        child: _isSubmitting
                            ? SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: tk.onPrimary,
                                  semanticsLabel: _isSignUp
                                      ? 'Mendaftar'
                                      : 'Masuk',
                                ),
                              )
                            : Text(_isSignUp ? 'Daftar' : 'Masuk'),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            'Dengan melanjutkan, kamu menyetujui',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tk.textMuted,
                            ),
                          ),
                          TextButton(
                            onPressed: _openPrivacy,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              textStyle: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            child: const Text('Kebijakan Privasi'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// App icon on its own rounded tile (the PNG has an opaque white background,
/// so it is never drawn straight onto the page color), with the wordmark
/// underneath. The single focal point of the screen.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      children: <Widget>[
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: tk.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Image.asset(
              'assets/branding/tk_icon.png',
              fit: BoxFit.cover,
              semanticLabel: 'Logo Teman Kereta',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Teman Kereta',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: tk.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.isSignUp, required this.onChanged});

  final bool isSignUp;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const <ButtonSegment<bool>>[
        ButtonSegment<bool>(value: false, label: Text('Masuk')),
        ButtonSegment<bool>(value: true, label: Text('Daftar')),
      ],
      selected: <bool>{isSignUp},
      onSelectionChanged: onChanged == null
          ? null
          : (set) => onChanged!(set.first),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll<Size>(Size.fromHeight(48)),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TkRadius.control),
          ),
        ),
        side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: tk.border)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? tk.primary : tk.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? tk.onPrimary : tk.text,
        ),
        textStyle: WidgetStatePropertyAll<TextStyle?>(
          Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tk.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        child,
      ],
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
    setState(() {
      _isSending = false;
      if (error == null) {
        _sent = true;
      } else {
        _error = error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AlertDialog(
      title: const Text('Lupa kata sandi?'),
      content: _sent
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.mark_email_read_rounded,
                  size: 48,
                  color: tk.success,
                ),
                const SizedBox(height: 12),
                Text(
                  'Link reset kata sandi sudah dikirim ke ${widget.emailController.text.trim()}.\n\nCek inbox atau folder Spam.',
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Masukkan email akunmu. Kami kirim link untuk membuat kata sandi baru.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: widget.emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const <String>[AutofillHints.email],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => unawaited(_send()),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(
                        Icons.mail_outline_rounded,
                        color: tk.textMuted,
                      ),
                    ),
                    validator: validateEmail,
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    AuthNotice(message: _error!),
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
                onPressed: _isSending
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: _isSending ? null : _send,
                child: _isSending
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: tk.onPrimary,
                          semanticsLabel: 'Mengirim',
                        ),
                      )
                    : const Text('Kirim link'),
              ),
            ],
    );
  }
}
