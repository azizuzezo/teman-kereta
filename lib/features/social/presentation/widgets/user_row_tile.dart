import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/tk_logo.dart';
import '../../../../domain/entities/social_models.dart';
import 'follow_button.dart';

/// A single user row (avatar, display name, @username, follow button) —
/// shared by the user-search results, followers list, and following list so
/// all three look and behave identically.
class UserRowTile extends StatelessWidget {
  const UserRowTile({required this.user, super.key});

  final UserSummary user;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;
    return ListTile(
      onTap: () => context.push('/social/user/${user.id}'),
      leading: CircleAvatar(
        radius: 22,
        backgroundImage: hasAvatar
            ? CachedNetworkImageProvider(user.avatarUrl!)
            : null,
        child: hasAvatar ? null : const TkLogo(size: 28, showLabel: false),
      ),
      title: Text(user.resolvedName),
      subtitle: (user.username != null && user.username!.isNotEmpty)
          ? Text('@${user.username}')
          : null,
      trailing: FollowButton(targetUserId: user.id),
    );
  }
}
