import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'social_providers.dart';
import 'widgets/user_list_body.dart';

class FollowingListPage extends ConsumerWidget {
  const FollowingListPage({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(userFollowingProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Mengikuti')),
      body: SafeArea(
        child: UserListBody(
          users: following,
          errorMessage: 'Daftar yang diikuti belum bisa dimuat. Coba lagi.',
          emptyIcon: Icons.people_outline_rounded,
          emptyTitle: 'Belum mengikuti siapa pun',
          emptyMessage: 'Cari pengguna lain untuk mulai mengikuti.',
          emptyAction: FilledButton(
            onPressed: () => context.push('/social/search'),
            child: const Text('Cari pengguna'),
          ),
          onRefresh: () async {
            ref.invalidate(userFollowingProvider(userId));
            try {
              await ref.read(userFollowingProvider(userId).future);
            } on Object {
              // The body shows its own error state.
            }
          },
        ),
      ),
    );
  }
}
