import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/theme/app_theme.dart';

/// Halaman donasi pengembang di Patungan Yuk!.
final Uri developerSupportUri = Uri.parse('https://patungan.gifts/dev?lang=id');

/// Cadangan bila QRIS native belum bisa dibuat: halaman patungan.gifts/dev
/// sebagai popup (bottom sheet) di dalam aplikasi.
Future<void> showDeveloperSupportWebSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: dialogContext.tk.surface,
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TkRadius.card),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.85,
        ),
        child: const _SupportSheet(),
      ),
    ),
  );
}

bool _isPatunganHost(String host) =>
    host == 'patungan.gifts' || host.endsWith('.patungan.gifts');

class _SupportSheet extends StatefulWidget {
  const _SupportSheet();

  @override
  State<_SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends State<_SupportSheet> {
  late final WebViewController _controller;
  var _progress = 0;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    final controller = WebViewController();
    _controller = controller;
    unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(controller.setBackgroundColor(Colors.white));
    unawaited(
      controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _failed = false);
          },
          onWebResourceError: (error) {
            if ((error.isForMainFrame ?? true) && mounted) {
              setState(() => _failed = true);
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (!request.isMainFrame ||
                uri == null ||
                _isPatunganHost(uri.host)) {
              return NavigationDecision.navigate;
            }
            // Tautan keluar dari Patungan (mis. syarat pihak lain) dibuka di
            // browser, bukan di dalam popup.
            unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
            return NavigationDecision.prevent;
          },
        ),
      ),
    );
    unawaited(controller.loadRequest(developerSupportUri));
  }

  void _retry() {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    unawaited(_controller.loadRequest(developerSupportUri));
  }

  Future<void> _openInBrowser() async {
    try {
      await launchUrl(developerSupportUri, mode: LaunchMode.externalApplication);
    } on Object {
      // Tidak ada yang bisa dilakukan lagi; popup tetap terbuka.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Dukung Pengembang',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Tutup',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        if (_progress < 100 && !_failed)
          LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100),
        Expanded(
          child: _failed
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 40,
                          color: tk.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Halaman donasi belum bisa dimuat',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Periksa koneksi internet, lalu coba lagi.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tk.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _retry,
                          child: const Text('Coba lagi'),
                        ),
                        TextButton(
                          onPressed: () => unawaited(_openInBrowser()),
                          child: const Text('Buka di browser'),
                        ),
                      ],
                    ),
                  ),
                )
              : WebViewWidget(controller: _controller),
        ),
      ],
    );
  }
}
