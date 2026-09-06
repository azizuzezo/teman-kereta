import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../follow_controller.dart';

/// Renders nothing when [targetUserId] is the signed-in user (can't follow
/// yourself — also enforced by a DB check constraint as a backstop) or when
/// no one is signed in.
class FollowButton extends ConsumerWidget {
  const FollowButton({required this.targetUserId, super.key});

  final String targetUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == targetUserId) {
      return const SizedBox.shrink();
    }

    final following = ref.watch(isFollowingProvider(targetUserId));

    return following.when(
      loading: () => const SizedBox(
        width: 84,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
      data: (isFollowing) {
        return SizedBox(
          height: 32,
          child: isFollowing
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _toggle(context, ref, isFollowing),
                  child: const Text('Mengikuti'),
                )
              : FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _toggle(context, ref, isFollowing),
                  child: const Text('Ikuti'),
                ),
        );
      },
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool currentlyFollowing,
  ) async {
    final error = await ref
        .read(followControllerProvider.notifier)
        .toggleFollow(targetUserId, currentlyFollowing);
    ref.invalidate(isFollowingProvider(targetUserId));
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
