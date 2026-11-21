import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/support_dev_web_sheet.dart';
import '../data/dev_donation_api.dart';
import '../data/donor_contact.dart';

/// Popup di tengah layar "Dukung Pengembang": pilih nominal, QRIS tampil di dalam aplikasi, dan
/// layar berubah sendiri begitu pembayaran terdeteksi. QRIS dan konfirmasinya
/// dibuat oleh Patungan Yuk! (patungan.gifts/dev); aplikasi hanya
/// menampilkannya.
Future<void> showDevDonationSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: dialogContext.tk.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TkRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: const DevDonationSheet(),
      ),
    ),
  );
}

/// Nominal cepat, sama dengan pilihan di halaman patungan.gifts/dev.
const List<(String, int)> _presets = <(String, int)>[
  ('1 kopi', 10000),
  ('3 kopi', 30000),
  ('5 kopi', 50000),
];

String _rp(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return 'Rp$buffer';
}

enum _Stage { choose, creating, pay, paid, expired }

class DevDonationSheet extends ConsumerStatefulWidget {
  const DevDonationSheet({super.key});

  @override
  ConsumerState<DevDonationSheet> createState() => _DevDonationSheetState();
}

class _DevDonationSheetState extends ConsumerState<DevDonationSheet> {
  final TextEditingController _custom = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _message = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  /// Pengaturan QRIS yang berlaku sekarang di Patungan (GoPay atau Mayar),
  /// dibaca berulang selama layar terbuka sehingga formnya ikut berubah begitu
  /// pemilik mengganti pilihannya di Patungan.
  DevDonationConfig _config = DevDonationConfig.fallback;

  /// Server pembayaran terjangkau. False bila pembacaan pengaturan gagal; QRIS
  /// tidak bisa dibuat sampai tersambung lagi.
  bool _online = true;
  bool _configLoaded = false;
  Timer? _configTimer;
  Timer? _amountDebounce;

  _Stage _stage = _Stage.choose;
  int _preset = 10000;
  bool _useCustom = false;
  String? _error;
  bool _showWebFallback = false;

  DevDonationQris? _qris;
  Timer? _poll;
  Timer? _tick;
  Duration _skew = Duration.zero;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshConfig());
    _configTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_stage == _Stage.choose) unawaited(_refreshConfig());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _configTimer?.cancel();
    _amountDebounce?.cancel();
    _custom.dispose();
    _name.dispose();
    _message.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Email akun yang sedang masuk dan nomor HP yang sudah tersimpan di akun itu.
  DonorContactStore get _contacts => ref.read(donorContactStoreProvider);

  Future<void> _refreshConfig() async {
    final amount = _amount;
    try {
      final config = await ref
          .read(devDonationApiProvider)
          .config(amount: amount != null && amount > 0 ? amount : null);
      if (!mounted) return;
      if (config != _config || !_online || !_configLoaded) {
        setState(() {
          _config = config;
          _online = true;
          _configLoaded = true;
        });
      }
    } on DevDonationException {
      if (mounted && _online) setState(() => _online = false);
    }
  }

  /// Nominal berubah: QRIS yang berlaku bisa berbeda per nominal, baca ulang.
  void _amountChanged() {
    _amountDebounce?.cancel();
    _amountDebounce = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_refreshConfig()),
    );
  }

  int? get _amount {
    if (!_useCustom) return _preset;
    return int.tryParse(_custom.text.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  Future<void> _create() async {
    final amount = _amount;
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Isi nominal dulu.');
      return;
    }
    // Kontak hanya dikirim bila QRIS yang aktif memintanya (Mayar). Email dari
    // akun yang masuk; nomor HP dari akun bila sudah pernah disimpan.
    String? email;
    String? phone;
    String? typedPhone;
    if (_config.requiresEmail) {
      email = _contacts.email ?? _email.text.trim();
      if (!isValidDonorEmail(email)) {
        setState(() => _error = 'Isi alamat email yang benar.');
        return;
      }
    }
    if (_config.requiresPhone) {
      final saved = _contacts.phone;
      phone = saved ?? _phone.text.trim();
      if (!isValidDonorPhone(phone)) {
        setState(() => _error = 'Isi nomor HP yang benar, contoh: 08123456789.');
        return;
      }
      if (saved == null) typedPhone = phone;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _stage = _Stage.creating;
      _error = null;
      _showWebFallback = false;
    });
    try {
      final qris = await ref
          .read(devDonationApiProvider)
          .create(
            amount: amount,
            name: _name.text,
            message: _message.text,
            email: email,
            phone: phone,
          );
      if (!mounted) return;
      // Nomor HP baru disimpan di akun supaya donasi berikutnya tidak perlu
      // mengisinya lagi.
      if (typedPhone != null) unawaited(_contacts.savePhone(typedPhone));
      setState(() {
        _qris = qris;
        _stage = _Stage.pay;
        _skew = Duration.zero;
      });
      _startWatching(qris);
    } on DevDonationException catch (e) {
      if (!mounted) return;
      if (e.needsContact) {
        // Pemilik baru saja memilih QRIS yang mewajibkan kontak: tampilkan
        // isiannya dan minta dilengkapi.
        setState(() {
          _stage = _Stage.choose;
          _config = DevDonationConfig(
            provider: _config.provider,
            requiresEmail: _config.requiresEmail || e.needsEmail,
            requiresPhone: _config.requiresPhone || e.needsPhone,
            minAmount: _config.minAmount,
          );
          _error = 'Lengkapi data di bawah, lalu coba lagi.';
        });
        return;
      }
      setState(() {
        _stage = _Stage.choose;
        _error = e.message;
        _showWebFallback = e.retryable;
      });
    }
  }

  void _startWatching(DevDonationQris qris) {
    _poll?.cancel();
    _tick?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_check(qris));
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock(qris));
    _updateClock(qris);
  }

  void _updateClock(DevDonationQris qris) {
    final expires = qris.expiresAt;
    if (expires == null || !mounted) return;
    final left = expires.difference(DateTime.now().add(_skew));
    if (left <= Duration.zero) {
      _stopWatching();
      setState(() => _stage = _Stage.expired);
      return;
    }
    setState(() => _remaining = left);
  }

  Future<void> _check(DevDonationQris qris) async {
    final status = await ref.read(devDonationApiProvider).status(qris.trxId);
    if (!mounted || _qris?.trxId != qris.trxId || _stage != _Stage.pay) return;
    final serverNow = status.serverNow;
    if (serverNow != null) _skew = serverNow.difference(DateTime.now());
    switch (status.state) {
      case DevDonationState.paid:
        _stopWatching();
        unawaited(HapticFeedback.mediumImpact());
        setState(() => _stage = _Stage.paid);
      case DevDonationState.expired:
        _stopWatching();
        setState(() => _stage = _Stage.expired);
      case DevDonationState.pending || DevDonationState.unknown:
        break;
    }
  }

  void _stopWatching() {
    _poll?.cancel();
    _tick?.cancel();
    _poll = null;
    _tick = null;
  }

  void _again() {
    _stopWatching();
    setState(() {
      _qris = null;
      _remaining = null;
      _stage = _Stage.choose;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Dialog sudah menggeser isinya saat keyboard muncul.
    return Padding(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
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
            const SizedBox(height: 8),
            switch (_stage) {
              _Stage.choose => _buildChoose(context),
              _Stage.creating => const _Centered(
                label: 'Membuat QRIS...',
                child: CircularProgressIndicator(),
              ),
              _Stage.pay => _buildPay(context),
              _Stage.paid => _buildPaid(context),
              _Stage.expired => _buildExpired(context),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildChoose(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Teman Kereta gratis dan tanpa iklan. Kalau membantu, ikut patungan '
          'untuk biaya server dan pengembangan.',
          style: theme.textTheme.bodyMedium?.copyWith(color: tk.textMuted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final (label, value) in _presets)
              ChoiceChip(
                label: Text('$label  ${_rp(value)}'),
                selected: !_useCustom && _preset == value,
                onSelected: (_) {
                  setState(() {
                    _useCustom = false;
                    _preset = value;
                    _error = null;
                  });
                  _amountChanged();
                },
              ),
            ChoiceChip(
              label: const Text('Nominal lain'),
              selected: _useCustom,
              onSelected: (_) {
                setState(() {
                  _useCustom = true;
                  _error = null;
                });
                _amountChanged();
              },
            ),
          ],
        ),
        if (_useCustom) ...<Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: _custom,
            onChanged: (_) => _amountChanged(),
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          maxLength: 40,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama (opsional)',
            hintText: 'Kosong dicatat sebagai Anonim',
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _message,
          maxLength: 200,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: const InputDecoration(
            labelText: 'Pesan (opsional)',
            counterText: '',
          ),
        ),
        ..._contactFields(context),
        if (!_online) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(Icons.wifi_off_rounded, size: 18, color: tk.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tidak tersambung ke server pembayaran. Periksa internet; '
                  'akan dicoba lagi otomatis.',
                  style: theme.textTheme.bodySmall?.copyWith(color: tk.danger),
                ),
              ),
            ],
          ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: tk.danger)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _online ? _create : null,
          icon: const Icon(Icons.qr_code_2_rounded),
          label: const Text('Buat QRIS'),
        ),
        if (_showWebFallback)
          TextButton(
            onPressed: () => unawaited(showDeveloperSupportWebSheet(context)),
            child: const Text('Bayar lewat halaman web'),
          ),
      ],
    );
  }

  /// Isian kontak yang diminta QRIS aktif. Email tidak ditampilkan bila akun
  /// sudah punya; nomor HP tidak ditampilkan bila sudah tersimpan di akun.
  List<Widget> _contactFields(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    final needEmail = _config.requiresEmail && _contacts.email == null;
    final needPhone = _config.requiresPhone && _contacts.phone == null;
    if (!_config.requiresEmail && !_config.requiresPhone) return const <Widget>[];
    return <Widget>[
      if (needEmail) ...<Widget>[
        const SizedBox(height: 8),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const <String>[AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
      ],
      if (needPhone) ...<Widget>[
        const SizedBox(height: 8),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const <String>[AutofillHints.telephoneNumber],
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Nomor HP',
            hintText: '08123456789',
            helperText: 'Disimpan di akunmu, cukup diisi sekali.',
          ),
        ),
      ],
      if (!needEmail && !needPhone) ...<Widget>[
        const SizedBox(height: 8),
        Text(
          'Pembayaran memakai email akunmu dan nomor HP yang tersimpan.',
          style: theme.textTheme.bodySmall?.copyWith(color: tk.textMuted),
        ),
      ],
    ];
  }

  Widget _buildPay(BuildContext context) {
    final qris = _qris!;
    final tk = context.tk;
    final theme = Theme.of(context);
    final remaining = _remaining;
    final mm = remaining == null
        ? null
        : '${remaining.inMinutes.toString().padLeft(2, '0')}:'
              '${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
    final code = qris.qrisCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tk.border),
            ),
            child: code != null
                ? QrImageView(
                    data: code,
                    size: 240,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  )
                : Image.network(
                    qris.qrImageUrl,
                    width: 240,
                    height: 240,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 240,
                      height: 240,
                      child: Center(child: Text('QR belum bisa ditampilkan')),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _rp(qris.amount),
            style: theme.textTheme.headlineMedium,
          ),
        ),
        Center(
          child: Text(
            qris.uniqueCode > 0
                ? 'Sudah termasuk kode unik ${_rp(qris.uniqueCode)}'
                    '${qris.fee > 0 ? ' dan biaya QRIS ${_rp(qris.fee)}' : ''}, '
                    'supaya pembayaran terdeteksi otomatis. Bayar sesuai nominal ini.'
                : 'Bayar sesuai nominal ini supaya terdeteksi otomatis.',
            style: theme.textTheme.bodySmall?.copyWith(color: tk.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                mm == null
                    ? 'Menunggu pembayaran...'
                    : 'Menunggu pembayaran, sisa $mm',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Buka aplikasi bank atau e-wallet, pilih Scan QRIS. Di HP yang sama, '
          'screenshot layar ini lalu pilih dari galeri.',
          style: theme.textTheme.bodySmall?.copyWith(color: tk.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPaid(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        const SizedBox(height: 12),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: tk.successSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 40, color: tk.success),
        ),
        const SizedBox(height: 16),
        Text('Terima kasih!', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Dukunganmu sudah masuk. Teman Kereta tetap gratis berkat kamu.',
          style: theme.textTheme.bodyMedium?.copyWith(color: tk.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Selesai'),
        ),
      ],
    );
  }

  Widget _buildExpired(BuildContext context) {
    final tk = context.tk;
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        const SizedBox(height: 12),
        Icon(Icons.timer_off_outlined, size: 40, color: tk.textMuted),
        const SizedBox(height: 12),
        Text('QRIS sudah kedaluwarsa', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Belum ada pembayaran yang masuk. Buat QRIS baru kalau masih mau mendukung.',
          style: theme.textTheme.bodyMedium?.copyWith(color: tk.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _again, child: const Text('Buat QRIS baru')),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child, required this.label});

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: <Widget>[
          child,
          const SizedBox(height: 16),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
