import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/providers/provider_registry.dart';
import '../../app_config/presentation/app_config_controller.dart';
import '../domain/subscription_entitlement.dart';
import 'subscription_controller.dart';

/// Paywall for the premium "pengingat turun di stasiun" feature. Reached
/// either from onboarding-style upsell copy or when a signed-in-but-
/// unentitled user tries to enable the reminder in Settings.
class PremiumPaywallPage extends ConsumerStatefulWidget {
  const PremiumPaywallPage({super.key});

  @override
  ConsumerState<PremiumPaywallPage> createState() => _PremiumPaywallPageState();
}

class _PremiumPaywallPageState extends ConsumerState<PremiumPaywallPage> {
  Map<String, Object?>? _pendingPayment;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  Duration? _remaining;
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _createPayment() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'premium-create-payment',
      );
      final data = response.data;
      if (data is! Map || data['error'] != null) {
        setState(() {
          _error = data is Map
              ? '${data['error']}'
              : 'Gagal membuat pembayaran. Coba lagi.';
        });
        return;
      }
      setState(() => _pendingPayment = Map<String, Object?>.from(data));
      final url = data['qris_url'] as String?;
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      _startPolling();
      _startCountdown();
    } on Object {
      setState(() => _error = 'Gagal membuat pembayaran. Periksa koneksi lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    final expiresAt = DateTime.tryParse(
      _pendingPayment?['expires_at'] as String? ?? '',
    );
    if (expiresAt == null) return;
    void tick() {
      final now = ref.read(clockProvider).now();
      final remaining = expiresAt.difference(now);
      setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
      if (remaining.isNegative) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _checkPayment());
  }

  Future<void> _checkPayment() async {
    final paymentId = _pendingPayment?['payment_id'];
    if (paymentId == null) return;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'premium-check-payment',
        body: {'payment_id': paymentId},
      );
      final data = response.data;
      if (data is Map && data['paid'] == true) {
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        unawaited(ref.read(subscriptionControllerProvider.notifier).refresh());
        if (mounted) {
          setState(() => _pendingPayment = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pembayaran berhasil — premium aktif.')),
          );
          unawaited(Navigator.of(context).maybePop());
        }
      }
    } on Object {
      // Keep polling — a single failed check isn't worth surfacing an error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(subscriptionControllerProvider);
    final config = ref.watch(appConfigControllerProvider);
    final priceText = NumberFormat.decimalPattern('id_ID').format(config.premiumPriceIdr);

    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Pengingat turun di stasiun',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Notifikasi otomatis beberapa stasiun sebelum tujuanmu — fitur premium.',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rp $priceText / ${config.premiumPeriodDays} hari',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(_statusLabel(entitlement)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_pendingPayment != null) _buildPendingPaymentCard(context),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _creating || _pendingPayment != null ? null : _createPayment,
              child: _creating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Bayar dengan QRIS'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingPaymentCard(BuildContext context) {
    final url = _pendingPayment?['qris_url'] as String?;
    final remaining = _remaining;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Menunggu pembayaran…'),
            const SizedBox(height: 8),
            if (remaining != null)
              Text(
                'Kedaluwarsa dalam ${remaining.inMinutes.toString().padLeft(2, '0')}:'
                '${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
              ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                if (url != null)
                  TextButton(
                    onPressed: () =>
                        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                    child: const Text('Buka halaman QRIS lagi'),
                  ),
                TextButton(
                  onPressed: _checkPayment,
                  child: const Text('Cek status sekarang'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(SubscriptionEntitlement entitlement) {
    final now = ref.read(clockProvider).now();
    switch (entitlement.status) {
      case SubscriptionStatus.trialing:
        if (entitlement.isEntitledAt(now) && entitlement.trialEndsAt != null) {
          final daysLeft = entitlement.trialEndsAt!.difference(now).inDays;
          return 'Masa coba gratis: $daysLeft hari lagi.';
        }
        return 'Masa coba gratis sudah berakhir.';
      case SubscriptionStatus.active:
        if (entitlement.isEntitledAt(now) && entitlement.currentPeriodEnd != null) {
          final formatted = DateFormat('d MMM y', 'id_ID').format(entitlement.currentPeriodEnd!);
          return 'Aktif sampai $formatted.';
        }
        return 'Langganan sudah berakhir.';
      case SubscriptionStatus.expired:
        return 'Langganan sudah berakhir.';
      case SubscriptionStatus.none:
        return 'Belum berlangganan.';
    }
  }
}
