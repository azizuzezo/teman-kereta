import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/tk_components.dart';

/// Loading placeholder shaped like feed posts (avatar, name line, two body
/// lines, action row) with hairline dividers, so the real list replaces it
/// without the layout jumping.
class ForumPostSkeleton extends StatelessWidget {
  const ForumPostSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      label: 'Memuat postingan',
      child: Column(
        children: <Widget>[
          for (var i = 0; i < count; i++) ...<Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TkSkeleton(height: 40, width: 40, radius: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TkSkeleton(height: 14, width: 150),
                        SizedBox(height: 10),
                        TkSkeleton(height: 12),
                        SizedBox(height: 6),
                        TkSkeleton(height: 12, width: 220),
                        SizedBox(height: 14),
                        TkSkeleton(height: 12, width: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tk.border),
          ],
        ],
      ),
    );
  }
}

/// Skeleton for a list of user rows (followers, following, search results).
class UserRowSkeleton extends StatelessWidget {
  const UserRowSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Memuat pengguna',
      child: Column(
        children: <Widget>[
          for (var i = 0; i < count; i++)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: <Widget>[
                  TkSkeleton(height: 44, width: 44, radius: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TkSkeleton(height: 14, width: 140),
                        SizedBox(height: 8),
                        TkSkeleton(height: 12, width: 90),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  TkSkeleton(height: 34, width: 84, radius: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
