/// A lightweight snapshot of a `public.users` row. Shared across the forum
/// and social features wherever a post author, search result, or
/// follower/following row needs to render identity, so each feature doesn't
/// re-declare the same shape.
class UserSummary {
  const UserSummary({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.followerCount,
    this.followingCount,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      followerCount: json['follower_count'] as int?,
      followingCount: json['following_count'] as int?,
    );
  }

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final int? followerCount;
  final int? followingCount;

  /// Best available label: display name, falling back to `@username`, then a
  /// generic placeholder — mirrors the fallback chain already used for the
  /// current account in `profile_page.dart`.
  String get resolvedName {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!;
    }
    if (username != null && username!.trim().isNotEmpty) {
      return '@$username';
    }
    return 'Pengguna Teman Kereta';
  }
}
