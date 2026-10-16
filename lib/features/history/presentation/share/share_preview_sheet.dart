import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import 'share_card_renderer.dart';
import 'share_cards.dart';
import 'share_data.dart';

/// Bottom sheet that previews a share card, lets the rider pick 4:5 or 9:16,
/// and shares the rendered PNG. Failure keeps the sheet open with a message.
Future<void> showSharePreviewSheet(
  BuildContext context,
  ShareCardSpec spec, {
  ShareCardRenderer renderer = const ShareCardRenderer(),
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SharePreviewSheet(spec: spec, renderer: renderer),
  );
}

class SharePreviewSheet extends StatefulWidget {
  const SharePreviewSheet({
    required this.spec,
    super.key,
    this.renderer = const ShareCardRenderer(),
  });

  final ShareCardSpec spec;
  final ShareCardRenderer renderer;

  @override
  State<SharePreviewSheet> createState() => _SharePreviewSheetState();
}

class _SharePreviewSheetState extends State<SharePreviewSheet> {
  ShareAspect _aspect = ShareAspect.portrait;
  bool _busy = false;
  String? _error;

  Future<void> _share() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.renderer.share(context, widget.spec, _aspect);
    } on Object {
      if (!mounted) {
        return;
      }
      const message = 'Gagal membagikan gambar. Coba lagi.';
      setState(() => _error = message);
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final cardSize = _aspect.size;
    final ratio = cardSize.width / cardSize.height;
    final maxWidth = media.size.width - 32;
    final previewHeight = math.min(media.size.height * 0.5, maxWidth / ratio);
    final previewWidth = previewHeight * ratio;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.spec.sheetTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 14),
          Center(
            child: Semantics(
              image: true,
              label: 'Pratinjau kartu: ${widget.spec.caption}',
              child: ExcludeSemantics(
                child: Container(
                  width: previewWidth,
                  height: previewHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tk.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: cardSize.width,
                      height: cardSize.height,
                      child: widget.spec.buildCard(_aspect),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<ShareAspect>(
            style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48)),
            showSelectedIcon: false,
            segments: const <ButtonSegment<ShareAspect>>[
              ButtonSegment<ShareAspect>(
                value: ShareAspect.portrait,
                label: Text('Kartu 4:5'),
              ),
              ButtonSegment<ShareAspect>(
                value: ShareAspect.story,
                label: Text('Story 9:16'),
              ),
            ],
            selected: <ShareAspect>{_aspect},
            onSelectionChanged: _busy
                ? null
                : (selection) => setState(() => _aspect = selection.first),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(color: tk.danger),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _share,
            icon: _busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: tk.textMuted,
                    ),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: Text(_busy ? 'Menyiapkan gambar' : 'Bagikan'),
          ),
        ],
      ),
    );
  }
}
