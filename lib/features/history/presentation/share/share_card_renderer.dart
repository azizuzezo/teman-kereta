import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'share_cards.dart';
import 'share_data.dart';

/// Completes once the next frame has been painted. Injectable because widget
/// tests do not produce frames on their own.
typedef FrameWaiter = Future<void> Function();

/// Persists PNG bytes somewhere the platform share sheet can read.
typedef PngFileWriter = Future<XFile> Function(Uint8List bytes, String stem);

/// Renders a card widget to a PNG without showing it, then hands it to the
/// system share sheet.
///
/// The card is laid out inside an [OverlayEntry] far outside the visible area
/// (it still paints, which `Offstage` would prevent) wrapped in a
/// [RepaintBoundary], captured with `toImage(pixelRatio: 3)`, and the entry is
/// removed again. A 360x450 card therefore exports at 1080x1350.
class ShareCardRenderer {
  const ShareCardRenderer({
    this.pixelRatio = 3,
    this.waitForFrame = _waitForNextFrame,
    this.writeFile = _writeTempPng,
  });

  final double pixelRatio;
  final FrameWaiter waitForFrame;
  final PngFileWriter writeFile;

  /// PNG bytes of [card], laid out at exactly [size] logical pixels.
  Future<Uint8List> renderPng(
    BuildContext context,
    Widget card,
    Size size,
  ) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      throw StateError('Tidak ada Overlay untuk menggambar kartu.');
    }
    // The logo is an asset image; if it has not been decoded by the time the
    // frame paints, it would be missing from the exported card.
    try {
      await precacheImage(const AssetImage(_logoAsset), context);
    } on Object {
      // A missing logo must not block sharing the numbers.
    }

    final boundaryKey = GlobalKey();
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: -(size.width + 400),
        top: 0,
        width: size.width,
        height: size.height,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: RepaintBoundary(key: boundaryKey, child: card),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      await waitForFrame();
      var boundary = _boundary(boundaryKey);
      // In debug builds `toImage` asserts the boundary is painted.
      for (var i = 0; i < 4 && boundary.debugNeedsPaint; i++) {
        await waitForFrame();
        boundary = _boundary(boundaryKey);
      }
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('Gambar kartu kosong.');
        }
        return data.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      entry.remove();
      entry.dispose();
    }
  }

  RenderRepaintBoundary _boundary(GlobalKey key) {
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) {
      throw StateError('Kartu belum tergambar.');
    }
    return object;
  }

  /// Renders [spec] at [aspect] and opens the share sheet with the image and
  /// the caption.
  Future<ShareResult> share(
    BuildContext context,
    ShareCardSpec spec,
    ShareAspect aspect,
  ) async {
    final bytes = await renderPng(context, spec.buildCard(aspect), aspect.size);
    final file = await writeFile(bytes, spec.fileStem);
    return SharePlus.instance.share(
      ShareParams(
        files: <XFile>[file],
        text: spec.caption,
        subject: 'Teman Kereta',
      ),
    );
  }
}

const _logoAsset = 'assets/branding/tk_icon.png';

Future<void> _waitForNextFrame() {
  SchedulerBinding.instance.scheduleFrame();
  return SchedulerBinding.instance.endOfFrame;
}

Future<XFile> _writeTempPng(Uint8List bytes, String stem) async {
  final directory = await getTemporaryDirectory();
  final name = '$stem-${DateTime.now().millisecondsSinceEpoch}.png';
  final file = File('${directory.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes, flush: true);
  return XFile(file.path, mimeType: 'image/png', name: name);
}
