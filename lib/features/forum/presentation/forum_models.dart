import 'package:flutter/material.dart';

import '../../../domain/entities/social_models.dart';

/// A forum post, with an optional embedded [author] snapshot (populated via
/// the `users(username, display_name, avatar_url)` nested select) and
/// [likedByMe] merged in separately from `forum_likes`, since Postgrest has
/// no single query that returns both a nested author row and "did the
/// current viewer like this" in one shot without a custom RPC.
class ForumPost {
  const ForumPost({
    required this.id,
    required this.userId,
    required this.body,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
    this.imageUrl,
    this.lineId,
    this.author,
    this.likedByMe = false,
  });

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    final authorJson = json['users'] as Map<String, dynamic>?;
    return ForumPost(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      body: json['body'] as String,
      imageUrl: json['image_url'] as String?,
      lineId: json['line_id'] as String?,
      likeCount: (json['like_count'] as int?) ?? 0,
      commentCount: (json['comment_count'] as int?) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      author: authorJson == null
          ? null
          : UserSummary.fromJson(<String, dynamic>{
              'id': json['user_id'],
              ...authorJson,
            }),
    );
  }

  final String id;
  final String userId;
  final String body;
  final String? imageUrl;
  final String? lineId;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final UserSummary? author;
  final bool likedByMe;

  ForumPost copyWith({
    String? body,
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
  }) {
    return ForumPost(
      id: id,
      userId: userId,
      body: body ?? this.body,
      imageUrl: imageUrl,
      lineId: lineId,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
      author: author,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}

class ForumComment {
  const ForumComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.author,
  });

  factory ForumComment.fromJson(Map<String, dynamic> json) {
    final authorJson = json['users'] as Map<String, dynamic>?;
    return ForumComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      author: authorJson == null
          ? null
          : UserSummary.fromJson(<String, dynamic>{
              'id': json['user_id'],
              ...authorJson,
            }),
    );
  }

  final String id;
  final String postId;
  final String userId;
  final String body;
  final DateTime createdAt;
  final UserSummary? author;
}

/// A minimal row from `public.lines`, just enough to power the composer's
/// optional line-tag picker (there is no existing Flutter-side line list
/// provider to reuse — `transit_providers.dart` only exposes stations).
class LineOption {
  const LineOption({
    required this.id,
    required this.name,
    required this.code,
    this.color,
  });

  factory LineOption.fromJson(Map<String, dynamic> json) {
    return LineOption(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      color: json['color'] as String?,
    );
  }

  final String id;
  final String name;
  final String code;
  final String? color;

  /// [color] parsed to a paintable [Color], or null when missing/malformed.
  Color? get resolvedColor {
    final hex = color;
    if (hex == null || hex.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(hex.replaceFirst('#', '0xFF'));
    return parsed == null ? null : Color(parsed);
  }
}
