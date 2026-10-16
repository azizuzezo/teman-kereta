import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/tk_components.dart';
import '../../../forum/presentation/forum_controller.dart';
import '../../../forum/presentation/forum_session.dart';
import '../follow_controller.dart';
import '../social_providers.dart';

/// "Ikuti" / "Mengikuti" toggle. Flips immediately and reverts with a message
/// if the server refuses. Renders nothing when [targetUserId] is the
/// signed-in user (can't follow yourself, also enforced by a DB constraint)
/// or when no one is signed in.
///
/// Draws 36dp tall but keeps a 48dp tap area. [expanded] stretches it to the
/// full width (profile header).
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({
    required this.targetUserId,
    super.key,
    this.expanded = false,
  });

  final String targetUserId;
  final bool expanded;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool? _optimistic;
  bool _busy = false;

  Future<void> _toggle(bool currentlyFollowing) async {
    if (_busy) return;
    final target = widget.targetUserId;
    setState(() {
      _busy = true;
      _optimistic = !currentlyFollowing;
    });
    final error = await ref
        .read(followControllerProvider.notifier)
        .toggleFollow(target, currentlyFollowing);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _optimistic = currentlyFollowing;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _busy = false);
    ref.invalidate(isFollowingProvider(target));
    ref.invalidate(userSummaryProvider(target));
    final feed = ref.read(forumControllerProvider.notifier);
    if (feed.followingOnly) unawaited(feed.reload());
    try {
      await ref.read(isFollowingProvider(target).future);
    } on Object {
      // Keep showing the optimistic value.
    }
    if (mounted) setState(() => _optimistic = null);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = currentForumUserId();
    if (currentUserId == null || currentUserId == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    final async = ref.watch(isFollowingProvider(widget.targetUserId));
    final following = _optimistic ?? async.value;
    if (following == null) {
      if (async.hasError) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: TkSkeleton(height: 36, width: 88, radius: 12),
      );
    }

    final minimum = Size(widget.expanded ? double.infinity : 88, 36);
    const padding = EdgeInsets.symmetric(horizontal: 16);
    final button = following
        ? OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: minimum,
              padding: padding,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            onPressed: () => _toggle(following),
            child: const Text('Mengikuti'),
          )
        : FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: minimum,
              padding: padding,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            onPressed: () => _toggle(following),
            child: const Text('Ikuti'),
          );
    return button;
  }
}
