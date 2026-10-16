import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';

/// The one password input used across the app (login, sign-up, confirm,
/// reset). Adds a show/hide eye toggle with a tooltip and screen reader label,
/// and turns off suggestions and autocorrect so the password never leaks into
/// the keyboard dictionary.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    super.key,
    this.hintText,
    this.helperText,
    this.validator,
    this.autofillHints = const <String>[AutofillHints.password],
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.focusNode,
    this.enabled = true,
    this.autovalidateMode,
    this.prefixIcon = Icons.lock_outline_rounded,
  });

  final TextEditingController controller;
  final String? hintText;
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final Iterable<String> autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool enabled;
  final AutovalidateMode? autovalidateMode;
  final IconData? prefixIcon;

  static const String showLabel = 'Tampilkan kata sandi';
  static const String hideLabel = 'Sembunyikan kata sandi';

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  void _toggle() => setState(() => _obscured = !_obscured);

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final label = _obscured ? PasswordField.showLabel : PasswordField.hideLabel;
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      autovalidateMode: widget.autovalidateMode,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      inputFormatters: <TextInputFormatter>[
        // A pasted password with a trailing newline would silently never match.
        FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
      ],
      decoration: InputDecoration(
        hintText: widget.hintText,
        helperText: widget.helperText,
        helperMaxLines: 2,
        errorMaxLines: 3,
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, color: tk.textMuted),
        suffixIcon: Semantics(
          button: true,
          label: label,
          onTap: widget.enabled ? _toggle : null,
          excludeSemantics: true,
          child: IconButton(
            tooltip: label,
            onPressed: widget.enabled ? _toggle : null,
            icon: Icon(
              _obscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: tk.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
