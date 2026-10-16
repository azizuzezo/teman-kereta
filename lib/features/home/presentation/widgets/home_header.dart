import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';

/// Greeting row: logo tile, time-based greeting and the notification bell.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.greeting,
    required this.dateLabel,
    super.key,
  });

  final String greeting;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Semantics(
          label: 'Teman Kereta',
          image: true,
          child: Container(
            width: 44,
            height: 44,
            // The icon PNG carries its own opaque background, so it sits
            // on a bordered rounded tile instead of the page color.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: tk.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/branding/tk_icon.png',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium,
              ),
              Text(
                greeting,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Pusat notifikasi',
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}
