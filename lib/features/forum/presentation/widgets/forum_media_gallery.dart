import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_theme.dart';
import '../forum_media.dart';

/// A post's photos and videos, Threads style: one item at its own shape
/// (portrait stays portrait), several as a sideways-scrolling row of equal
/// height. Tapping opens them full screen.
class ForumMediaGallery extends StatelessWidget {
  const ForumMediaGallery({
    required this.media,
    this.onDoubleTap,
    super.key,
  });

  final List<ForumMedia> media;
  final VoidCallback? onDoubleTap;

  static const _singleMaxHeight = 420.0;
  static const _rowHeight = 260.0;

  void _open(BuildContext context, int index) {
    unawaited(
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => ForumMediaViewer(media: media, initialIndex: index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    if (media.length == 1) {
      final item = media.single;
      // Posts from before media sizes were stored: let the image take its
      // own shape once loaded instead of forcing a guessed 4:3 crop.
      if (!item.isVideo && (item.width == null || item.height == null)) {
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _singleMaxHeight),
              child: Semantics(
                button: true,
                image: true,
                label: 'Foto postingan. Ketuk untuk memperbesar.',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => _open(context, 0),
                  onDoubleTap: onDoubleTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: item.url,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const SizedBox(
                        width: double.infinity,
                        height: 240,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final ratio = item.aspectRatio.clamp(0.6, 2.0);
          // Keep clear of the screen edge, as the post text does.
          final maxWidth = constraints.maxWidth - 16;
          var height = maxWidth / ratio;
          if (height > _singleMaxHeight) height = _singleMaxHeight;
          return Align(
            alignment: Alignment.centerLeft,
            child: _MediaTile(
              item: item,
              width: height * ratio,
              height: height,
              onTap: () => _open(context, 0),
              onDoubleTap: onDoubleTap,
            ),
          );
        },
      );
    }
    return SizedBox(
      height: _rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 16),
        itemCount: media.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = media[index];
          return _MediaTile(
            item: item,
            width: _rowHeight * item.aspectRatio.clamp(0.6, 1.6),
            height: _rowHeight,
            onTap: () => _open(context, index),
            onDoubleTap: onDoubleTap,
          );
        },
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.item,
    required this.width,
    required this.height,
    required this.onTap,
    this.onDoubleTap,
  });

  final ForumMedia item;
  final double width;
  final double height;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      button: true,
      image: !item.isVideo,
      label: item.isVideo
          ? 'Video postingan. Ketuk untuk memutar.'
          : 'Foto postingan. Ketuk untuk memperbesar.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          width: width,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: tk.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tk.border, width: 0.5),
          ),
          child: item.isVideo
              ? _VideoThumbnail(item: item)
              : CachedNetworkImage(
                  imageUrl: item.url,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Icon(
                    Icons.broken_image_outlined,
                    color: tk.textMuted,
                  ),
                ),
        ),
      ),
    );
  }
}

/// The video's first frame with a play badge and its length. The player is
/// only initialised far enough to paint that frame; nothing plays in the
/// feed.
class _VideoThumbnail extends StatefulWidget {
  const _VideoThumbnail({required this.item});

  final ForumMedia item;

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.item.url));
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      _controller
          .initialize()
          .then((_) {
            if (mounted) setState(() => _ready = true);
          })
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.item.duration ?? _controller.value.duration;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_ready)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
        const Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
        if (duration > Duration.zero)
          Positioned(
            left: 8,
            bottom: 8,
            child: _Badge(text: formatVideoDuration(duration)),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontFeatures: AppTheme.timeFeatures,
          ),
        ),
      ),
    );
  }
}

/// Full-screen swipeable viewer: photos pinch-zoom, videos play with a
/// scrubber.
class ForumMediaViewer extends StatefulWidget {
  const ForumMediaViewer({
    required this.media,
    this.initialIndex = 0,
    super.key,
  });

  final List<ForumMedia> media;
  final int initialIndex;

  @override
  State<ForumMediaViewer> createState() => _ForumMediaViewerState();
}

class _ForumMediaViewerState extends State<ForumMediaViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.media.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: count > 1 ? Text('${_index + 1} / $count') : null,
        leading: IconButton(
          tooltip: 'Tutup',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: count,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) {
          final item = widget.media[index];
          if (item.isVideo) {
            return _FullVideo(item: item, active: index == _index);
          }
          return InteractiveViewer(
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: item.url,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FullVideo extends StatefulWidget {
  const _FullVideo({required this.item, required this.active});

  final ForumMedia item;

  /// The page currently shown: plays when it becomes active, pauses when
  /// swiped away.
  final bool active;

  @override
  State<_FullVideo> createState() => _FullVideoState();
}

class _FullVideoState extends State<_FullVideo> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.item.url));
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      _controller
          .initialize()
          .then((_) {
            if (!mounted) return;
            setState(() => _ready = true);
            unawaited(_controller.setLooping(true));
            if (widget.active) unawaited(_controller.play());
          })
          .catchError((Object _) {}),
    );
  }

  @override
  void didUpdateWidget(_FullVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready || oldWidget.active == widget.active) return;
    unawaited(widget.active ? _controller.play() : _controller.pause());
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _toggle() {
    setState(() {
      if (_controller.value.isPlaying) {
        unawaited(_controller.pause());
      } else {
        unawaited(_controller.play());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller,
            builder: (context, value, _) => value.isPlaying
                ? const SizedBox.shrink()
                : const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white70,
                    size: 72,
                  ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
