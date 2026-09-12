import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/config/app_environment.dart';
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
  /// Selected line to filter the feed by, or null for every post. Kept as
  /// controller state rather than [ForumFeedState] since it's an input to
  /// fetching, not a fetched result — [loadMore] reads it via [_fetchPage]
  /// exactly like it already reads `before`.
  String? _lineFilter;

  String? get lineFilter => _lineFilter;

  @override
  Future<ForumFeedState> build() => _fetchPage();

  /// Switches the feed to only posts tagged with [lineId] (or every post, for
  /// null) and reloads from the first page.
  Future<void> setLineFilter(String? lineId) async {
    if (_lineFilter == lineId) return;
    _lineFilter = lineId;
    await refresh();
  }

  Future<ForumFeedState> _fetchPage({DateTime? before}) async {
    if (!AppEnvironment.supabaseEnabled) {
      return const ForumFeedState(posts: <ForumPost>[], hasMore: false);
    }
    var query = Supabase.instance.client
        .from('forum_posts')
        .select('*, $_postAuthorSelect')
        .eq('status', 'visible');
    if (_lineFilter != null) {
      query = query.eq('line_id', _lineFilter!);
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
    final merged = <ForumPost>[
      for (final post in posts)
        post.copyWith(likedByMe: liked.contains(post.id)),
    ];
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

  Future<List<ForumComment>> fetchComments(String postId) async {
    final rows =
        await Supabase.instance.client
                .from('forum_comments')
                .select('*, $_commentAuthorSelect')
                .eq('post_id', postId)
                .eq('status', 'visible')
                .order('created_at')
            as List<dynamic>;
    return rows
        .map((row) => ForumComment.fromJson(row as Map<String, dynamic>))
        .toList();
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

/// Re-fetched (and cached) per post id; callers invalidate this after
/// [ForumController.addComment] succeeds to pick up the new comment.
final forumCommentsProvider = FutureProvider.family<List<ForumComment>, String>(
  (ref, postId) {
    return ref.read(forumControllerProvider.notifier).fetchComments(postId);
  },
);

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
