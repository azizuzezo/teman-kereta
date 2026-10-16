import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/config/app_environment.dart';
import '../../account/presentation/account_controller.dart';
import 'forum_models.dart';

const _pageSize = 20;
// PostgREST can reach `users` from `forum_posts` two ways (directly via
// forum_posts.user_id, and indirectly through forum_likes) -- the bare
// `users(...)` embed is ambiguous (PGRST201) without naming the FK.
// forum_comments has no such second path, but names its FK explicitly too
// for the same clarity/robustness.
const _postAuthorSelect =
    'users!forum_posts_user_id_fkey(username, display_name, avatar_url)';
const _commentAuthorSelect =
    'users!forum_comments_user_id_fkey(username, display_name, avatar_url)';

class ForumFeedState {
  const ForumFeedState({required this.posts, required this.hasMore});

  static const empty = ForumFeedState(posts: <ForumPost>[], hasMore: true);

  final List<ForumPost> posts;
  final bool hasMore;

  ForumFeedState copyWith({List<ForumPost>? posts, bool? hasMore}) {
    return ForumFeedState(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Feed of visible forum posts, newest first, with pagination and the usual
/// like/comment/delete side-effects. Comments themselves are fetched
/// on-demand per post via [fetchComments] (backed by [forumCommentsProvider]
/// below) rather than kept in this state, since only one post's comment
/// thread is ever open at a time.
class ForumController extends AsyncNotifier<ForumFeedState> {
  /// Current feed narrowing (line tag and/or "Mengikuti"). Kept as controller
  /// state rather than [ForumFeedState] since it's an input to fetching, not
  /// a fetched result — [loadMore] reads it via [_fetchPage] exactly like it
  /// already reads `before`.
  ForumFeedFilter _filter = ForumFeedFilter.all;

  ForumFeedFilter get filter => _filter;

  String? get lineFilter => _filter.lineId;

  bool get followingOnly => _filter.followingOnly;

  @override
  Future<ForumFeedState> build() => _fetchPage();

  /// Switches the feed to only posts tagged with [lineId] (or every post, for
  /// null) and reloads from the first page.
  Future<void> setLineFilter(String? lineId) async {
    if (_filter.lineId == lineId) return;
    _filter = _filter.withLine(lineId);
    await refresh();
  }

  /// Switches between every post and only posts from accounts the signed-in
  /// user follows, and reloads from the first page.
  Future<void> setFollowingOnly({required bool value}) async {
    if (_filter.followingOnly == value) return;
    _filter = _filter.withFollowingOnly(value: value);
    await refresh();
  }

  Future<ForumFeedState> _fetchPage({DateTime? before}) async {
    if (!AppEnvironment.supabaseEnabled) {
      return const ForumFeedState(posts: <ForumPost>[], hasMore: false);
    }
    List<String>? followeeIds;
    if (_filter.followingOnly) {
      final me = Supabase.instance.client.auth.currentUser?.id;
      if (me != null) {
        final followRows =
            await Supabase.instance.client
                    .from('user_follows')
                    .select('followee_id')
                    .eq('follower_id', me)
                as List<dynamic>;
        followeeIds = followRows
            .map(
              (row) => (row as Map<String, dynamic>)['followee_id'] as String,
            )
            .toList();
      }
      if (followeeIds == null || followeeIds.isEmpty) {
        return const ForumFeedState(posts: <ForumPost>[], hasMore: false);
      }
    }
    var query = Supabase.instance.client
        .from('forum_posts')
        .select('*, $_postAuthorSelect')
        .eq('status', 'visible');
    if (_filter.lineId != null) {
      query = query.eq('line_id', _filter.lineId!);
    }
    if (followeeIds != null) {
      query = query.inFilter('user_id', followeeIds);
    }
    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }
    final rows =
        await query.order('created_at', ascending: false).limit(_pageSize)
            as List<dynamic>;
    final posts = rows
        .map((row) => ForumPost.fromJson(row as Map<String, dynamic>))
        .toList();
    final liked = await _fetchLikedPostIds(posts.map((p) => p.id).toList());
    final blocked = await ref.read(blockedUserIdsProvider.future);
    final merged = <ForumPost>[
      for (final post in posts)
        if (!blocked.contains(post.userId))
          post.copyWith(likedByMe: liked.contains(post.id)),
    ];
    // `hasMore` reflects the raw page, not the filtered one, so blocking
    // everyone on a page doesn't end pagination early.
    return ForumFeedState(posts: merged, hasMore: posts.length == _pageSize);
  }

  Future<Set<String>> _fetchLikedPostIds(List<String> postIds) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || postIds.isEmpty) return <String>{};
    final rows =
        await Supabase.instance.client
                .from('forum_likes')
                .select('post_id')
                .eq('user_id', userId)
                .inFilter('post_id', postIds)
            as List<dynamic>;
    return rows
        .map((row) => (row as Map<String, dynamic>)['post_id'] as String)
        .toSet();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchPage);
  }

  /// Pull-to-refresh: re-fetches the first page without blanking the list
  /// first, and keeps what is showing if the fetch fails. Returns whether it
  /// succeeded.
  Future<bool> reload() async {
    final result = await AsyncValue.guard(_fetchPage);
    if (result.hasError) return false;
    state = result;
    return true;
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.posts.isEmpty) return;
    try {
      final next = await _fetchPage(before: current.posts.last.createdAt);
      state = AsyncValue.data(
        current.copyWith(
          posts: <ForumPost>[...current.posts, ...next.posts],
          hasMore: next.hasMore,
        ),
      );
    } on Object {
      // Leave the current page showing; the load-more control stays
      // visible so the user can retry.
    }
  }

  /// Returns an error message on failure, or null on success.
  Future<String?> createPost(
    String body, {
    Uint8List? imageBytes,
    String? lineId,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 'Masuk untuk membuat postingan.';
    final trimmed = body.trim();
    if (trimmed.isEmpty) return 'Tulis sesuatu dulu sebelum posting.';
    try {
      final postId = const Uuid().v4();
      String? imageUrl;
      if (imageBytes != null) {
        final path = '$userId/$postId/${const Uuid().v4()}.jpg';
        await Supabase.instance.client.storage
            .from('forum-post-images')
            .uploadBinary(
              path,
              imageBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        imageUrl = Supabase.instance.client.storage
            .from('forum-post-images')
            .getPublicUrl(path);
      }
      await Supabase.instance.client
          .from('forum_posts')
          .insert(<String, Object?>{
            'id': postId,
            'user_id': userId,
            'body': trimmed,
            'image_url': ?imageUrl,
            'line_id': ?lineId,
          });
      await refresh();
      return null;
    } on Object {
      return 'Gagal membuat postingan. Coba lagi.';
    }
  }

  Future<void> toggleLike(String postId, bool currentlyLiked) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          posts: <ForumPost>[
            for (final post in current.posts)
              if (post.id == postId)
                post.copyWith(
                  likedByMe: !currentlyLiked,
                  likeCount: currentlyLiked
                      ? post.likeCount - 1
                      : post.likeCount + 1,
                )
              else
                post,
          ],
        ),
      );
    }
    try {
      if (currentlyLiked) {
        await Supabase.instance.client
            .from('forum_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        await Supabase.instance.client.from('forum_likes').insert(
          <String, Object?>{'post_id': postId, 'user_id': userId},
        );
      }
    } on Object {
      // Revert the optimistic update by re-syncing with the server.
      await refresh();
    }
  }

  /// Returns an error message on failure, or null on success. RLS already
  /// restricts this update to the post's own owner and to the `body`
  /// column.
  Future<String?> updatePost(String postId, String newBody) async {
    final trimmed = newBody.trim();
    if (trimmed.isEmpty) return 'Postingan tidak boleh kosong.';
    try {
      await Supabase.instance.client
          .from('forum_posts')
          .update({'body': trimmed})
          .eq('id', postId);
      final current = state.asData?.value;
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(
            posts: <ForumPost>[
              for (final post in current.posts)
                if (post.id == postId) post.copyWith(body: trimmed) else post,
            ],
          ),
        );
      }
      return null;
    } on Object {
      return 'Gagal menyimpan perubahan. Coba lagi.';
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await Supabase.instance.client
          .from('forum_posts')
          .delete()
          .eq('id', postId);
      final current = state.asData?.value;
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(
            posts: current.posts.where((p) => p.id != postId).toList(),
          ),
        );
      }
    } on Object {
      // Leave the post showing; nothing useful to surface here beyond a
      // failed tap, and the owner can retry.
    }
  }

  /// Checks the current feed page first (cheap, no round-trip) before
  /// falling back to a direct fetch — e.g. for a post opened from another
  /// user's profile page rather than scrolled-to in the feed.
  Future<ForumPost?> fetchPost(String postId) async {
    for (final post in state.asData?.value.posts ?? const <ForumPost>[]) {
      if (post.id == postId) return post;
    }
    try {
      final row = await Supabase.instance.client
          .from('forum_posts')
          .select('*, $_postAuthorSelect')
          .eq('id', postId)
          .maybeSingle();
      if (row == null) return null;
      final post = ForumPost.fromJson(row);
      final liked = await _fetchLikedPostIds(<String>[postId]);
      return post.copyWith(likedByMe: liked.contains(postId));
    } on Object {
      return null;
    }
  }

  /// Visible posts by [userId], newest first, with the viewer's own likes
  /// merged in (for another user's profile page).
  Future<List<ForumPost>> fetchUserPosts(String userId) async {
    final rows =
        await Supabase.instance.client
                .from('forum_posts')
                .select('*, $_postAuthorSelect')
                .eq('user_id', userId)
                .eq('status', 'visible')
                .order('created_at', ascending: false)
                .limit(50)
            as List<dynamic>;
    final posts = rows
        .map((row) => ForumPost.fromJson(row as Map<String, dynamic>))
        .toList();
    final liked = await _fetchLikedPostIds(posts.map((p) => p.id).toList());
    return <ForumPost>[
      for (final post in posts)
        post.copyWith(likedByMe: liked.contains(post.id)),
    ];
  }

  Future<List<ForumComment>> fetchComments(String postId) async {
    final rows =
        await Supabase.instance.client
                .from('forum_comments')
                .select('*, $_commentAuthorSelect')
                .eq('post_id', postId)
                .eq('status', 'visible')
                .order('created_at')
            as List<dynamic>;
    final blocked = await ref.read(blockedUserIdsProvider.future);
    return rows
        .map((row) => ForumComment.fromJson(row as Map<String, dynamic>))
        .where((comment) => !blocked.contains(comment.userId))
        .toList();
  }

  /// Files a report against a post or comment (exactly one of [postId] /
  /// [commentId]) for the moderators to review. Reporting the same item twice
  /// is treated as success. Returns an error message, or null on success.
  Future<String?> reportContent({
    String? postId,
    String? commentId,
    required String reason,
    String? details,
  }) async {
    assert((postId == null) != (commentId == null));
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 'Masuk untuk melaporkan konten.';
    final trimmed = details?.trim();
    try {
      await Supabase.instance.client
          .from('forum_reports')
          .insert(<String, Object?>{
            'reporter_id': userId,
            'post_id': ?postId,
            'comment_id': ?commentId,
            'reason': reason,
            if (trimmed != null && trimmed.isNotEmpty) 'details': trimmed,
          });
      return null;
    } on PostgrestException catch (error) {
      if (error.code == '23505') return null; // already reported by this user
      return 'Gagal mengirim laporan. Coba lagi.';
    } on Object {
      return 'Gagal mengirim laporan. Coba lagi.';
    }
  }

  /// Blocks [targetUserId]: their posts and comments disappear from this
  /// user's feed and threads. Returns an error message, or null on success.
  Future<String?> blockUser(String targetUserId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 'Masuk untuk memblokir pengguna.';
    if (userId == targetUserId) {
      return 'Kamu tidak bisa memblokir dirimu sendiri.';
    }
    try {
      await Supabase.instance.client.from('user_blocks').insert(
        <String, Object?>{'blocker_id': userId, 'blocked_id': targetUserId},
      );
    } on PostgrestException catch (error) {
      if (error.code != '23505') return 'Gagal memblokir pengguna. Coba lagi.';
    } on Object {
      return 'Gagal memblokir pengguna. Coba lagi.';
    }
    await _refreshAfterBlockChange();
    return null;
  }

  /// Block lists are applied when data is fetched, so every cached thread
  /// fetched before the change (comments of any post) must be dropped too,
  /// or a blocked user's comments stay visible (or stay hidden after unblock).
  Future<void> _refreshAfterBlockChange() async {
    ref.invalidate(blockedUserIdsProvider);
    ref.invalidate(blockedUsersProvider);
    ref.invalidate(forumCommentsProvider);
    await refresh();
  }

  Future<String?> unblockUser(String targetUserId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 'Masuk untuk mengelola blokir.';
    try {
      await Supabase.instance.client
          .from('user_blocks')
          .delete()
          .eq('blocker_id', userId)
          .eq('blocked_id', targetUserId);
    } on Object {
      return 'Gagal membuka blokir. Coba lagi.';
    }
    await _refreshAfterBlockChange();
    return null;
  }

  /// Returns an error message on failure, or null on success.
  Future<String?> addComment(String postId, String body) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 'Masuk untuk berkomentar.';
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      await Supabase.instance.client.from('forum_comments').insert(
        <String, Object?>{
          'post_id': postId,
          'user_id': userId,
          'body': trimmed,
        },
      );
      final current = state.asData?.value;
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(
            posts: <ForumPost>[
              for (final post in current.posts)
                if (post.id == postId)
                  post.copyWith(commentCount: post.commentCount + 1)
                else
                  post,
            ],
          ),
        );
      }
      return null;
    } on Object {
      return 'Gagal mengirim komentar. Coba lagi.';
    }
  }

  /// Returns an error message on failure, or null on success. RLS already
  /// restricts this update to the comment's own owner and to the `body`
  /// column. Callers refresh the displayed thread via
  /// `ref.invalidate(forumCommentsProvider(postId))`.
  Future<String?> updateComment(String commentId, String newBody) async {
    final trimmed = newBody.trim();
    if (trimmed.isEmpty) return 'Komentar tidak boleh kosong.';
    try {
      await Supabase.instance.client
          .from('forum_comments')
          .update({'body': trimmed})
          .eq('id', commentId);
      return null;
    } on Object {
      return 'Gagal menyimpan perubahan. Coba lagi.';
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await Supabase.instance.client
          .from('forum_comments')
          .delete()
          .eq('id', commentId);
    } on Object {
      // Leave the comment showing; nothing useful to surface here beyond a
      // failed tap, and the owner can retry.
    }
  }

  Future<List<LineOption>> fetchLineOptions() async {
    try {
      final rows =
          await Supabase.instance.client
                  .from('lines')
                  .select('id, name, code, color')
                  .eq('is_active', true)
                  .order('name')
              as List<dynamic>;
      return rows
          .map((row) => LineOption.fromJson(row as Map<String, dynamic>))
          .toList();
    } on Object {
      return const <LineOption>[];
    }
  }
}

final forumControllerProvider =
    AsyncNotifierProvider<ForumController, ForumFeedState>(ForumController.new);

final forumPostProvider = FutureProvider.family<ForumPost?, String>((
  ref,
  postId,
) {
  return ref.read(forumControllerProvider.notifier).fetchPost(postId);
});

/// Posts written by one user (their profile page).
final forumUserPostsProvider = FutureProvider.autoDispose
    .family<List<ForumPost>, String>((ref, userId) {
      return ref.read(forumControllerProvider.notifier).fetchUserPosts(userId);
    });

/// Re-fetched (and cached) per post id; callers invalidate this after
/// [ForumController.addComment] succeeds to pick up the new comment.
final forumCommentsProvider = FutureProvider.family<List<ForumComment>, String>(
  (ref, postId) {
    return ref.read(forumControllerProvider.notifier).fetchComments(postId);
  },
);

/// Ids of users the signed-in account has blocked; empty when signed out.
/// Re-fetched when the signed-in account changes.
final blockedUserIdsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(accountControllerProvider).asData?.value;
  if (user == null || !AppEnvironment.supabaseEnabled) return <String>{};
  try {
    final rows =
        await Supabase.instance.client
                .from('user_blocks')
                .select('blocked_id')
                .eq('blocker_id', user.id)
            as List<dynamic>;
    return rows
        .map((row) => (row as Map<String, dynamic>)['blocked_id'] as String)
        .toSet();
  } on Object {
    // Blocking is a convenience filter; fail open rather than hide the forum.
    return <String>{};
  }
});

/// A blocked user, with enough profile data to show in the "blocked users"
/// list.
class BlockedUser {
  const BlockedUser({required this.id, required this.name});

  final String id;
  final String name;
}

final blockedUsersProvider = FutureProvider<List<BlockedUser>>((ref) async {
  final user = ref.watch(accountControllerProvider).asData?.value;
  if (user == null || !AppEnvironment.supabaseEnabled) return const [];
  final rows =
      await Supabase.instance.client
              .from('user_blocks')
              .select(
                'blocked_id, users!user_blocks_blocked_id_fkey(username, display_name)',
              )
              .eq('blocker_id', user.id)
              .order('created_at', ascending: false)
          as List<dynamic>;
  return <BlockedUser>[
    for (final raw in rows)
      () {
        final row = raw as Map<String, dynamic>;
        final profile = row['users'] as Map<String, dynamic>?;
        final username = profile?['username'] as String?;
        final displayName = profile?['display_name'] as String?;
        final name = (username != null && username.isNotEmpty)
            ? '@$username'
            : (displayName != null && displayName.isNotEmpty)
            ? displayName
            : 'Pengguna Teman Kereta';
        return BlockedUser(id: row['blocked_id'] as String, name: name);
      }(),
  ];
});

final forumLineOptionsProvider = FutureProvider<List<LineOption>>((ref) {
  return ref.read(forumControllerProvider.notifier).fetchLineOptions();
});

/// [forumLineOptionsProvider], keyed by id — how [ForumPostCard] resolves a
/// post's `lineId` to its display name/color without a linear scan per post.
final forumLineOptionsByIdProvider = FutureProvider<Map<String, LineOption>>((
  ref,
) async {
  final options = await ref.watch(forumLineOptionsProvider.future);
  return <String, LineOption>{for (final option in options) option.id: option};
});
