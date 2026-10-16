import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../auth_errors.dart';

/// Keeps only the digits of whatever was typed or pasted, so "123 456" and
/// "123-456" both land as `123456`, and cuts the result to [length].
class OtpDigitsFormatter extends TextInputFormatter {
  const OtpDigitsFormatter(this.length);

  final int length;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > length) digits = digits.substring(0, length);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

/// One real text field (so the keyboard, paste, and the autofill service for
/// one time codes all work) drawn as a row of per-digit boxes.
///
/// [onCompleted] fires once the last digit lands, whether typed or pasted.
class OtpInput extends StatefulWidget {
  const OtpInput({
    required this.controller,
    super.key,
    this.length = kOtpLength,
    this.onChanged,
    this.onCompleted,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
    this.focusNode,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    _focus.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focus.removeListener(_rebuild);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _handleChanged(String value) {
    widget.onChanged?.call(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final focused = _focus.hasFocus && widget.enabled;
    final activeIndex = text.length.clamp(0, widget.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final boxWidth =
            ((constraints.maxWidth - gap * (widget.length - 1)) / widget.length)
                .clamp(36.0, 56.0);
        final boxes = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (var i = 0; i < widget.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: gap),
              _DigitBox(
                width: boxWidth,
                digit: i < text.length ? text[i] : '',
                isActive: focused && i == activeIndex,
                hasError: widget.hasError,
                enabled: widget.enabled,
              ),
            ],
          ],
        );

        return Semantics(
          label: 'Kode verifikasi ${widget.length} digit',
          textField: true,
          child: SizedBox(
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // The real field spans the whole row so a tap anywhere opens
                // the keyboard; its text is transparent because the boxes
                // above draw the digits.
                Positioned.fill(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.oneTimeCode],
                    autocorrect: false,
                    enableSuggestions: false,
                    showCursor: false,
                    maxLength: null,
                    inputFormatters: <TextInputFormatter>[
                      OtpDigitsFormatter(widget.length),
                    ],
                    style: const TextStyle(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    decoration: const InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      counterText: '',
                    ),
                    onTap: () {
                      // Typing always appends: never leave the caret mid-code.
                      widget.controller.selection = TextSelection.collapsed(
                        offset: widget.controller.text.length,
                      );
                    },
                    onChanged: _handleChanged,
                  ),
                ),
                IgnorePointer(child: ExcludeSemantics(child: boxes)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({
    required this.width,
    required this.digit,
    required this.isActive,
    required this.hasError,
    required this.enabled,
  });

  final double width;
  final String digit;
  final bool isActive;
  final bool hasError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final Color borderColor = hasError
        ? tk.danger
        : isActive
        ? tk.primary
        : tk.border;
    final reduce = MediaQuery.of(context).disableAnimations;
    return AnimatedContainer(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 120),
      width: width,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? tk.surface : tk.surfaceAlt,
        borderRadius: BorderRadius.circular(TkRadius.control),
        border: Border.all(
          color: borderColor,
          width: isActive || hasError ? 2 : 1,
        ),
      ),
      child: Text(
        digit,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: tk.text,
          fontWeight: FontWeight.w700,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
