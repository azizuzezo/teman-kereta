import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import 'account_controller.dart';
import 'auth_errors.dart';
import 'widgets/auth_notice.dart';
import 'widgets/otp_input.dart';

/// Second step of sign-up: the user types the 6 digit code Supabase emailed.
/// Reached from the login page after `signUp`, or from sign-in when the
/// account exists but was never verified (`resendOnOpen`).
///
/// Until this succeeds Auth has issued no session, so the router's login gate
/// keeps the user out of the rest of the app.
class VerifyOtpPage extends ConsumerStatefulWidget {
  const VerifyOtpPage({
    required this.email,
    super.key,
    this.resendOnOpen = false,
  });

  final String email;

  /// Ask Auth for a fresh code as soon as the page opens.
  final bool resendOnOpen;

  @override
  ConsumerState<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends ConsumerState<VerifyOtpPage> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _ticker;
  int _remaining = 0;
  bool _verifying = false;
  bool _resending = false;
  bool _finishing = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    if (widget.email.isEmpty) {
      // Opened without an address (stale link): nothing to verify.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/account/login');
      });
    }
    _remaining = OtpCooldown.remaining(widget.email);
    _startTicker();
    if (widget.resendOnOpen && _remaining == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_resend()));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    if (_remaining <= 0) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      // Count ticks, but never show more than the wall clock allows: timers
      // stall while the app is in the background.
      final wall = OtpCooldown.remaining(widget.email);
      setState(
        () => _remaining = _remaining - 1 < wall ? _remaining - 1 : wall,
      );
      if (_remaining <= 0) timer.cancel();
    });
  }

  Future<void> _verify([String? value]) async {
    final code = value ?? _code.text;
    if (_verifying || _finishing) return;
    if (code.length != kOtpLength) {
      setState(() => _error = 'Masukkan $kOtpLength digit kode dari emailmu.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
      _info = null;
    });
    final error = await ref
        .read(accountControllerProvider.notifier)
        .verifySignupOtp(email: widget.email, code: code);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _verifying = false;
        _error = error;
      });
      _code.clear();
      // The field was disabled while verifying; refocus once it is enabled.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
      return;
    }
    await _finish();
  }

  /// Verified: a brand-new account still has no username, so pick one first.
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final username = await ref
        .read(accountControllerProvider.notifier)
        .fetchUsername();
    if (!mounted) return;
    context.go(
      username == null || username.isEmpty ? '/account/set-username' : '/',
    );
  }

  Future<void> _resend() async {
    if (_resending || _remaining > 0) return;
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    final error = await ref
        .read(accountControllerProvider.notifier)
        .resendSignupOtp(email: widget.email);
    if (!mounted) return;
    setState(() {
      _resending = false;
      _remaining = OtpCooldown.remaining(widget.email);
      if (error == null) {
        _info = 'Kode baru sudah dikirim. Cek emailmu.';
      } else {
        _error = error;
      }
    });
    _startTicker();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (data?.text ?? '').replaceAll(RegExp(r'\D'), '');
    if (!mounted) return;
    if (digits.length < kOtpLength) {
      setState(() => _error = 'Di clipboard belum ada kode $kOtpLength digit.');
      return;
    }
    final code = digits.substring(0, kOtpLength);
    _code.text = code;
    unawaited(_verify(code));
  }

  void _changeEmail() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/account/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    final busy = _verifying || _finishing;

    // A user who taps the link in the email instead of typing the code ends
    // up signed in; carry on the same way.
    ref.listen(accountControllerProvider, (previous, next) {
      if (next.asData?.value != null && !_finishing) unawaited(_finish());
    });

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: busy ? null : _changeEmail),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
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
                        Icons.mark_email_unread_outlined,
                        size: 32,
                        color: tk.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Masukkan kode verifikasi',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: tk.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        const TextSpan(
                          text: 'Kami mengirim kode $kOtpLength digit ke ',
                        ),
                        TextSpan(
                          text: maskEmail(widget.email),
                          style: TextStyle(
                            color: tk.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                          text: '. Cek juga folder Spam kalau belum masuk.',
                        ),
                      ],
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tk.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  OtpInput(
                    controller: _code,
                    focusNode: _focus,
                    hasError: _error != null,
                    enabled: !busy,
                    onChanged: (_) {
                      if (_error != null || _info != null) {
                        setState(() {
                          _error = null;
                          _info = null;
                        });
                      }
                    },
                    onCompleted: (code) => unawaited(_verify(code)),
                  ),
                  Align(
                    child: TextButton.icon(
                      onPressed: busy ? null : _paste,
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      label: const Text('Tempel kode'),
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 4),
                    AuthNotice(message: _error!),
                  ] else if (_info != null) ...<Widget>[
                    const SizedBox(height: 4),
                    AuthNotice(message: _info!, tone: AuthNoticeTone.success),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : () => unawaited(_verify()),
                    child: busy
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: tk.onPrimary,
                              semanticsLabel: 'Memverifikasi',
                            ),
                          )
                        : const Text('Verifikasi'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      TextButton(
                        onPressed: (_remaining > 0 || _resending || busy)
                            ? null
                            : () => unawaited(_resend()),
                        child: Text(
                          _resending
                              ? 'Mengirim...'
                              : _remaining > 0
                              ? 'Kirim ulang dalam ${formatCountdown(_remaining)}'
                              : 'Kirim ulang kode',
                          style: const TextStyle(
                            fontFeatures: <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: busy ? null : _changeEmail,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Ganti email'),
                      ),
                    ],
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
