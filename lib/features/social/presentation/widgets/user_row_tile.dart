import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/tk_components.dart';
import '../../../../domain/entities/social_models.dart';
import '../../../forum/presentation/forum_format.dart';
import 'follow_button.dart';

/// A single user row (avatar, name, @username, follow button), shared by
/// user search, the followers list and the following list so all three look
/// and behave identically.
class UserRowTile extends StatelessWidget {
  const UserRowTile({required this.user, super.key});

  final UserSummary user;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = forumAuthorLabel(user);
    return InkWell(
      onTap: () => context.push('/social/user/${user.id}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              TkAvatar(name: label.name, imageUrl: user.avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                    if (label.handle != null)
                      Text(
                        label.handle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FollowButton(targetUserId: user.id),
            ],
          ),
        ),
      ),
    );
  }
}
