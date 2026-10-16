import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/tk_components.dart';
import '../../../../domain/entities/social_models.dart';
import '../../../forum/presentation/widgets/forum_skeletons.dart';
import 'user_row_tile.dart';

/// Body shared by the followers and following screens: skeleton while
/// loading, retry on error, an empty state, otherwise hairline-separated
/// [UserRowTile]s with pull-to-refresh.
class UserListBody extends StatelessWidget {
  const UserListBody({
    required this.users,
    required this.onRefresh,
    required this.errorMessage,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    super.key,
    this.emptyAction,
  });

  final AsyncValue<List<UserSummary>> users;
  final Future<void> Function() onRefresh;
  final String errorMessage;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return users.when(
      loading: () => const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: UserRowSkeleton(),
      ),
      error: (error, stack) =>
          TkErrorState(message: errorMessage, onRetry: () => onRefresh()),
      data: (list) {
        if (list.isEmpty) {
          return AppEmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            message: emptyMessage,
            action: emptyAction,
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, indent: 72, color: tk.border),
            itemBuilder: (context, index) => UserRowTile(user: list[index]),
          ),
        );
      },
    );
  }
}
