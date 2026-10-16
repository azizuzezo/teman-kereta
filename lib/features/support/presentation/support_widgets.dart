import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/tk_components.dart';

/// Page body shared by About, Privacy and Help so the three read as one set:
/// same gutter, same max width on tablets, same bottom padding.
class SupportPageBody extends StatelessWidget {
  const SupportPageBody({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Plain paragraph in the body style, muted by default for secondary text.
class SupportParagraph extends StatelessWidget {
  const SupportParagraph(this.text, {super.key, this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: muted ? tk.textMuted : tk.text,
        height: 1.45,
      ),
    );
  }
}

/// One privacy/info block: icon tile, bold title, wrapped body.
class SupportInfoBlock extends StatelessWidget {
  const SupportInfoBlock({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tk.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: tk.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: textTheme.bodyMedium?.copyWith(
                    color: tk.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bordered group of [SupportInfoBlock]s separated by hairlines.
class SupportInfoGroup extends StatelessWidget {
  const SupportInfoGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Material(
      color: tk.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TkRadius.card),
        side: BorderSide(color: tk.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, indent: 66, color: tk.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Collapsible FAQ entry. Question is the tap target (>= 56dp).
class SupportFaqTile extends StatelessWidget {
  const SupportFaqTile({
    required this.question,
    required this.answer,
    super.key,
  });

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: tk.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TkRadius.card),
          side: BorderSide(color: tk.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            minTileHeight: 56,
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            expandedAlignment: Alignment.centerLeft,
            iconColor: tk.textMuted,
            collapsedIconColor: tk.textMuted,
            title: Text(question, style: textTheme.titleSmall),
            children: <Widget>[
              Text(
                answer,
                style: textTheme.bodyMedium?.copyWith(
                  color: tk.textMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section heading used consistently across the support pages.
class SupportSectionLabel extends StatelessWidget {
  const SupportSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TkSectionLabel(label),
    );
  }
}
