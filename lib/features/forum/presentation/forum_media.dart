import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Most attachments a post can carry; matched by the `forum_posts.media`
/// check constraint.
const forumMaxMedia = 4;

/// Longest video a post accepts.
const forumMaxVideoDuration = Duration(seconds: 60);

/// Largest video file accepted, matched by the `forum-post-media` bucket's
/// size limit.
const forumMaxVideoBytes = 50 * 1024 * 1024;

enum ForumMediaType { image, video }

/// How a photo is framed in the feed: cropped to 4:3, or at its own shape.
enum ForumMediaFit { original, fourByThree }

/// One photo or video attached to a post, as stored in `forum_posts.media`.
class ForumMedia {
  const ForumMedia({
    required this.url,
    required this.type,
    this.width,
    this.height,
    this.duration,
    this.fit = ForumMediaFit.original,
  });

  static ForumMedia? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final url = raw['url'];
    if (url is! String || url.isEmpty) return null;
    final duration = (raw['duration_ms'] as num?)?.toInt();
    return ForumMedia(
      url: url,
      type: raw['type'] == 'video' ? ForumMediaType.video : ForumMediaType.image,
      width: (raw['width'] as num?)?.toInt(),
      height: (raw['height'] as num?)?.toInt(),
      duration: duration == null ? null : Duration(milliseconds: duration),
      fit: raw['fit'] == '4:3'
          ? ForumMediaFit.fourByThree
          : ForumMediaFit.original,
    );
  }

  final String url;
  final ForumMediaType type;
  final int? width;
  final int? height;
  final Duration? duration;
  final ForumMediaFit fit;

  bool get isVideo => type == ForumMediaType.video;

  /// Width over height as it should be laid out, 4:3 when unknown.
  double get aspectRatio {
    if (fit == ForumMediaFit.fourByThree) return 4 / 3;
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return 4 / 3;
    return w / h;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'url': url,
    'type': isVideo ? 'video' : 'image',
    'width': ?width,
    'height': ?height,
    'duration_ms': ?duration?.inMilliseconds,
    if (fit == ForumMediaFit.fourByThree) 'fit': '4:3',
  };
}

/// A picked file waiting to be uploaded with a new post.
class ForumMediaDraft {
  ForumMediaDraft({
    required this.file,
    required this.type,
    required this.width,
    required this.height,
    this.duration,
    this.fit = ForumMediaFit.original,
  });

  final XFile file;
  final ForumMediaType type;
  final int width;
  final int height;
  final Duration? duration;
  ForumMediaFit fit;

  bool get isVideo => type == ForumMediaType.video;

  double get aspectRatio =>
      fit == ForumMediaFit.fourByThree || height <= 0 ? 4 / 3 : width / height;

  String get contentType {
    final mime = file.mimeType;
    if (mime != null && mime.isNotEmpty) return mime;
    final name = file.name.toLowerCase();
    if (isVideo) {
      if (name.endsWith('.mov')) return 'video/quicktime';
      if (name.endsWith('.webm')) return 'video/webm';
      return 'video/mp4';
    }
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String get extension {
    final dot = file.name.lastIndexOf('.');
    if (dot >= 0 && dot < file.name.length - 1) {
      return file.name.substring(dot + 1).toLowerCase();
    }
    return isVideo ? 'mp4' : 'jpg';
  }
}

/// Why a picked file was left out, shown to the rider.
class ForumMediaRejection implements Exception {
  const ForumMediaRejection(this.message);
  final String message;
}

bool _looksLikeVideo(XFile file) {
  final mime = file.mimeType;
  if (mime != null) return mime.startsWith('video/');
  final name = file.name.toLowerCase();
  return name.endsWith('.mp4') ||
      name.endsWith('.mov') ||
      name.endsWith('.webm') ||
      name.endsWith('.3gp') ||
      name.endsWith('.mkv');
}

/// Reads the size (and, for a video, the length) of [file] and checks it
/// against the post limits.
Future<ForumMediaDraft> readForumMediaDraft(XFile file) async {
  if (_looksLikeVideo(file)) {
    final bytes = await file.length();
    if (bytes > forumMaxVideoBytes) {
      throw const ForumMediaRejection('Ukuran video maksimal 50 MB.');
    }
    final controller = VideoPlayerController.file(File(file.path));
    try {
      await controller.initialize();
      final value = controller.value;
      if (value.duration > forumMaxVideoDuration + const Duration(seconds: 1)) {
        throw const ForumMediaRejection('Durasi video maksimal 60 detik.');
      }
      // A portrait phone video is stored landscape with a rotation flag.
      final quarterTurn = value.rotationCorrection % 180 != 0;
      final width = value.size.width.round();
      final height = value.size.height.round();
      return ForumMediaDraft(
        file: file,
        type: ForumMediaType.video,
        width: quarterTurn ? height : width,
        height: quarterTurn ? width : height,
        duration: value.duration,
      );
    } finally {
      await controller.dispose();
    }
  }
  final bytes = await file.readAsBytes();
  final size = await _imageSize(bytes);
  return ForumMediaDraft(
    file: file,
    type: ForumMediaType.image,
    width: size.width,
    height: size.height,
  );
}

Future<({int width, int height})> _imageSize(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final size = (width: descriptor.width, height: descriptor.height);
  descriptor.dispose();
  buffer.dispose();
  return size;
}

String formatVideoDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
