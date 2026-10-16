import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'social_providers.dart';
import 'widgets/user_list_body.dart';

class FollowersListPage extends ConsumerWidget {
  const FollowersListPage({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followers = ref.watch(userFollowersProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Pengikut')),
      body: SafeArea(
        child: UserListBody(
          users: followers,
          errorMessage: 'Daftar pengikut belum bisa dimuat. Coba lagi.',
          emptyIcon: Icons.people_outline_rounded,
          emptyTitle: 'Belum ada pengikut',
          emptyMessage: 'Akun yang mengikuti akan muncul di sini.',
          emptyAction: OutlinedButton(
            onPressed: () => context.push('/social/search'),
            child: const Text('Cari pengguna'),
          ),
          onRefresh: () async {
            ref.invalidate(userFollowersProvider(userId));
            try {
              await ref.read(userFollowersProvider(userId).future);
            } on Object {
              // The body shows its own error state.
            }
          },
        ),
      ),
    );
  }
}
