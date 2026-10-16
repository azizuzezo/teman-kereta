import 'package:flutter/material.dart';

import '../../../../core/utils/relative_time.dart';

/// "Name  @username  . 5 menit lalu" on one line. Name and @username are a
/// single ellipsizing run (the handle is cut first when space runs out) and
/// the time stays whole beside it.
class ForumByline extends StatelessWidget {
  const ForumByline({
    required this.name,
    required this.time,
    super.key,
    this.handle,
    this.onTap,
  });

  final String name;
  final String? handle;
  final DateTime time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final row = LayoutBuilder(
      builder: (context, constraints) => Row(
        children: <Widget>[
          Flexible(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: name, style: textTheme.titleSmall),
                  if (handle != null)
                    TextSpan(text: '  $handle', style: textTheme.bodySmall),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Capped so a long name can never push the row past its width.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.55),
            child: Text(
              ' · ${relativeTime(time)}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
