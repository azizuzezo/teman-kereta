import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

enum AuthNoticeTone { error, success, info }

/// Message block for results that belong to the whole form (wrong password,
/// no network, code sent) rather than to a single field. Announced to screen
/// readers when it appears.
class AuthNotice extends StatelessWidget {
  const AuthNotice({
    required this.message,
    super.key,
    this.tone = AuthNoticeTone.error,
  });

  final String message;
  final AuthNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final (Color bg, Color fg, IconData icon) = switch (tone) {
      AuthNoticeTone.error => (
        tk.dangerSoft,
        tk.danger,
        Icons.error_outline_rounded,
      ),
      AuthNoticeTone.success => (
        tk.successSoft,
        tk.success,
        Icons.check_circle_outline_rounded,
      ),
      AuthNoticeTone.info => (
        tk.primarySoft,
        tk.primary,
        Icons.info_outline_rounded,
      ),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(TkRadius.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tk.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
