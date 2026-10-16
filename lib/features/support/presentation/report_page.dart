import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/diagnostics/diagnostics_report.dart';
import '../../../core/widgets/tk_components.dart';
import '../data/report_sharer.dart';
import '../support_links.dart';
import 'report_controller.dart';
import 'support_widgets.dart';

/// Laporkan masalah (`/report`): category, message, optional contact, and a
/// visible preview of the log that travels with the report.
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  late final TextEditingController _message;
  late final TextEditingController _email;
  bool _previewOpen = false;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(reportControllerProvider);
    _message = TextEditingController(text: initial.message);
    _email = TextEditingController(text: initial.contactEmail);
    // Deliver reports that earlier attempts could not send.
    unawaited(
      Future<void>.microtask(
        () => ref.read(reportControllerProvider.notifier).retryPending(),
      ),
    );
  }

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final outcome = await ref
        .read(reportControllerProvider.notifier)
        .shareByEmail();
    if (!mounted) {
      return;
    }
    final text = switch (outcome) {
      ShareOutcome.sharedFile => null,
      ShareOutcome.openedMailDraft =>
        'Draft email dibuka. Tempel isi laporan di sana kalau belum terlampir.',
      ShareOutcome.failed =>
        'Tidak ada aplikasi email yang bisa dibuka. Kirim manual ke ${SupportLinks.supportEmail}.',
    };
    if (text != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _reset() {
    ref.read(reportControllerProvider.notifier).reset();
    final state = ref.read(reportControllerProvider);
    _message.text = '';
    _email.text = state.contactEmail;
    setState(() => _previewOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportControllerProvider);
    final body = switch (state.phase) {
      ReportPhase.sent => _SentView(
        referenceId: state.referenceId ?? '',
        onDone: () => Navigator.of(context).maybePop(),
        onAnother: _reset,
      ),
      ReportPhase.queued || ReportPhase.failed => _NotSentView(
        state: state,
        onRetry: () => ref.read(reportControllerProvider.notifier).retry(),
        onEmail: _share,
      ),
      _ => _FormView(
        state: state,
        message: _message,
        email: _email,
        previewOpen: _previewOpen,
        onTogglePreview: () {
          setState(() => _previewOpen = !_previewOpen);
          if (_previewOpen && state.previewText == null) {
            unawaited(
              ref.read(reportControllerProvider.notifier).loadPreview(),
            );
          }
        },
      ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Laporkan masalah')),
      body: SupportPageBody(children: <Widget>[body]),
    );
  }
}

class _FormView extends ConsumerWidget {
  const _FormView({
    required this.state,
    required this.message,
    required this.email,
    required this.previewOpen,
    required this.onTogglePreview,
  });

  final ReportState state;
  final TextEditingController message;
  final TextEditingController email;
  final bool previewOpen;
  final VoidCallback onTogglePreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(reportControllerProvider.notifier);
    final submitting = state.phase == ReportPhase.submitting;
    final categoryError = state.errors[ReportField.category];
    final trimmedLength = state.message.trim().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.lastFlushedCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TkCard(
              tone: TkCardTone.success,
              child: Text(
                '${state.lastFlushedCount} laporan yang tertunda sudah terkirim.',
                style: textTheme.bodyMedium,
              ),
            ),
          ),
        if (state.pendingCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TkCard(
              tone: TkCardTone.warning,
              child: Text(
                '${state.pendingCount} laporan masih menunggu koneksi. Kami mencobanya lagi setiap kali halaman ini dibuka.',
                style: textTheme.bodyMedium,
              ),
            ),
          ),
        if (state.failureMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TkCard(
              tone: TkCardTone.warning,
              child: Text(state.failureMessage!, style: textTheme.bodyMedium),
            ),
          ),
        Text(
          'Laporan masuk ke tim Teman Kereta dan kami baca di ${SupportLinks.supportEmail}.',
          style: textTheme.bodyMedium?.copyWith(
            color: tk.textMuted,
            height: 1.4,
          ),
        ),
        const SupportSectionLabel('Jenis masalah'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final category in ReportCategory.values)
              ChoiceChip(
                label: Text(category.label),
                selected: state.category == category,
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TkRadius.control),
                  side: BorderSide(
                    color: state.category == category ? tk.primary : tk.border,
                  ),
                ),
                selectedColor: tk.primarySoft,
                backgroundColor: tk.surface,
                labelStyle: textTheme.labelLarge?.copyWith(
                  color: state.category == category ? tk.primary : tk.text,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                onSelected: submitting
                    ? null
                    : (_) => controller.setCategory(category),
              ),
          ],
        ),
        if (categoryError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              categoryError,
              style: textTheme.bodySmall?.copyWith(color: tk.danger),
            ),
          ),
        const SupportSectionLabel('Ceritakan masalahnya'),
        TextField(
          controller: message,
          enabled: !submitting,
          minLines: 5,
          maxLines: 10,
          maxLength: kMaxReportMessageLength,
          textCapitalization: TextCapitalization.sentences,
          onChanged: controller.setMessage,
          decoration: InputDecoration(
            hintText:
                'Apa yang kamu lakukan, apa yang terjadi, dan apa yang kamu harapkan. Sebutkan stasiun atau jam kalau ada.',
            errorText: state.errors[ReportField.message],
            helperText: trimmedLength >= kMinReportMessageLength
                ? null
                : 'Minimal $kMinReportMessageLength karakter ($trimmedLength sekarang)',
            helperMaxLines: 2,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: 8),
        _ContactCard(
          state: state,
          controller: email,
          enabled: !submitting,
          onToggle: controller.setIncludeContactEmail,
          onChanged: controller.setContactEmail,
        ),
        const SizedBox(height: 12),
        _LogCard(
          state: state,
          enabled: !submitting,
          previewOpen: previewOpen,
          onToggleLogs: controller.setIncludeLogs,
          onTogglePreview: onTogglePreview,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: submitting
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  unawaited(controller.submit());
                },
          icon: submitting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: tk.onPrimary,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(submitting ? 'Mengirim laporan' : 'Kirim laporan'),
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.state,
    required this.controller,
    required this.enabled,
    required this.onToggle,
    required this.onChanged,
  });

  final ReportState state;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return TkCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Sertakan email untuk dihubungi',
                      style: textTheme.titleSmall,
                    ),
                    Text(
                      'Kami membalas ke email ini kalau butuh info tambahan. Tanpa ini, laporan hanya membawa id akunmu.',
                      style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: state.includeContactEmail,
                onChanged: enabled ? onToggle : null,
              ),
            ],
          ),
          if (state.includeContactEmail)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
                onChanged: onChanged,
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: state.errors[ReportField.email],
                  errorMaxLines: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.state,
    required this.enabled,
    required this.previewOpen,
    required this.onToggleLogs,
    required this.onTogglePreview,
  });

  final ReportState state;
  final bool enabled;
  final bool previewOpen;
  final ValueChanged<bool> onToggleLogs;
  final VoidCallback onTogglePreview;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return TkCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Sertakan log aplikasi', style: textTheme.titleSmall),
                    Text(
                      'Membantu kami menemukan penyebab masalah. Tidak berisi kata sandi.',
                      style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: state.includeLogs,
                onChanged: enabled ? onToggleLogs : null,
              ),
            ],
          ),
          if (!state.includeLogs)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: Text(
                'Tanpa log, kami lebih sulit mencari penyebabnya. Laporan tetap bisa dikirim.',
                style: textTheme.bodySmall?.copyWith(color: tk.warning),
              ),
            ),
          InkWell(
            onTap: onTogglePreview,
            borderRadius: BorderRadius.circular(TkRadius.control),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Log yang ikut terkirim',
                      style: textTheme.labelLarge?.copyWith(color: tk.primary),
                    ),
                  ),
                  Icon(
                    previewOpen
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: tk.primary,
                    semanticLabel: previewOpen
                        ? 'Tutup pratinjau log'
                        : 'Buka pratinjau log',
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          if (previewOpen)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 12),
              child: _PreviewBox(state: state),
            ),
        ],
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.state});

  final ReportState state;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    if (state.previewLoading || state.previewText == null) {
      return const TkSkeleton(height: 120, radius: 12);
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      width: double.infinity,
      decoration: BoxDecoration(
        color: tk.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            state.previewText!,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.35,
              color: tk.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _SentView extends StatelessWidget {
  const _SentView({
    required this.referenceId,
    required this.onDone,
    required this.onAnother,
  });

  final String referenceId;
  final VoidCallback onDone;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tk.successSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: tk.success, size: 32),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Laporan terkirim',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Terima kasih. Tim kami akan membacanya. Kalau perlu info tambahan dan kamu mencantumkan email, kami membalas ke sana.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: tk.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          TkCard(
            tone: TkCardTone.alt,
            child: Column(
              children: <Widget>[
                Text('Nomor laporan', style: textTheme.bodySmall),
                const SizedBox(height: 4),
                Semantics(
                  label: 'Nomor laporan $referenceId',
                  child: SelectableText(
                    '#$referenceId',
                    style: textTheme.headlineSmall?.copyWith(
                      fontFeatures: AppTheme.timeFeatures,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sebut nomor ini kalau kamu menghubungi kami lagi.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: '#$referenceId'),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nomor laporan disalin.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Salin nomor'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onDone, child: const Text('Selesai')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onAnother,
            child: const Text('Kirim laporan lain'),
          ),
        ],
      ),
    );
  }
}

class _NotSentView extends StatelessWidget {
  const _NotSentView({
    required this.state,
    required this.onRetry,
    required this.onEmail,
  });

  final ReportState state;
  final VoidCallback onRetry;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final queued = state.phase == ReportPhase.queued;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tk.warningSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, color: tk.warning, size: 30),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Laporan belum terkirim',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '${state.failureMessage ?? 'Pengiriman gagal.'} '
            '${queued ? 'Laporanmu aman di perangkat ini dan kami coba kirim lagi otomatis saat halaman ini dibuka.' : 'Laporan juga belum bisa disimpan di perangkat, jadi kirim lewat email supaya tidak hilang.'}',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: tk.textMuted,
              height: 1.4,
            ),
          ),
          if (state.referenceId != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Nomor laporan #${state.referenceId}',
              textAlign: TextAlign.center,
              style: textTheme.labelLarge,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba kirim lagi'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onEmail,
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Kirim lewat email'),
          ),
          const SizedBox(height: 8),
          Text(
            'Lewat email, berkas laporan (.txt) dilampirkan ke ${SupportLinks.supportEmail}.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
          ),
        ],
      ),
    );
  }
}
