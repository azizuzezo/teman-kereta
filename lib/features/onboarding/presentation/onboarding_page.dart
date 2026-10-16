import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/platform/native_trip_service.dart';
import '../../../core/preferences/preferences_store.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../core/widgets/tk_logo.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../schedule/presentation/widgets/station_picker_sheet.dart';
import '../../settings/presentation/settings_controller.dart';

const _stepCount = 4;

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _controller = PageController();
  var _page = 0;
  String? _homeStation;
  String? _workStation;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      appBar: AppBar(
        leading: _page > 0
            ? IconButton(
                tooltip: 'Kembali',
                onPressed: _back,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        actions: <Widget>[
          if (_page > 0)
            TextButton(onPressed: _finish, child: const Text('Lewati semua')),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Semantics(
                label: 'Langkah ${_page + 1} dari $_stepCount',
                excludeSemantics: true,
                child: Row(
                  children: List<Widget>.generate(_stepCount, (index) {
                    return Expanded(
                      child: AnimatedContainer(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        height: 4,
                        margin: EdgeInsets.only(
                          right: index == _stepCount - 1 ? 0 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: index <= _page ? tk.primary : tk.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (value) => setState(() => _page = value),
                children: <Widget>[
                  _WelcomeStep(onNext: _next),
                  _LocationStep(onRequest: _requestLocation, onSkip: _next),
                  _RemindersStep(
                    onRequestNotifications: _requestNotifications,
                    onRequestBattery: _requestBattery,
                    onNext: _next,
                  ),
                  _DailyRouteStep(
                    homeStation: _homeStation,
                    workStation: _workStation,
                    onHomeChanged: (value) =>
                        setState(() => _homeStation = value),
                    onWorkChanged: (value) =>
                        setState(() => _workStation = value),
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    final store = ref.read(preferencesStoreProvider);
    await store.setHomeStation(_homeStation);
    await store.setWorkStation(_workStation);
    await ref.read(settingsControllerProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go('/');
    }
  }

  void _next() {
    if (_page >= _stepCount - 1) {
      return;
    }
    _goTo(_page + 1);
  }

  void _back() {
    if (_page <= 0) {
      return;
    }
    _goTo(_page - 1);
  }

  void _goTo(int target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(target);
    } else {
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _requestLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        _showMessage('Aktifkan layanan lokasi perangkat, lalu coba lagi.');
        return;
      }
      final permission = await Geolocator.requestPermission();
      if (!mounted) {
        return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage(
          'Lokasi belum diizinkan. Jadwal tetap dapat digunakan tanpa lokasi.',
        );
      }
      _next();
    } on Object {
      if (mounted) {
        _showMessage('Izin lokasi belum tersedia pada perangkat ini.');
        _next();
      }
    }
  }

  /// Returns whether notifications ended up allowed.
  Future<bool> _requestNotifications() async {
    final granted = await ref
        .read(localNotificationServiceProvider)
        .requestPermission();
    if (mounted && !granted) {
      _showMessage(
        'Notifikasi belum diizinkan. Kamu dapat mengaktifkannya dari Profil.',
      );
    }
    return granted;
  }

  /// Opens the system battery-optimization dialog, then reports whether the
  /// app is now exempt (false also when the platform has no such setting).
  Future<bool> _requestBattery() async {
    try {
      final service = ref.read(nativeTripServiceProvider);
      await service.requestIgnoreBatteryOptimizations();
      final status = await service.getPermissionStatus();
      return status['batteryOptimizationIgnored'] == true;
    } on Object {
      return false;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Shared frame of every step: scrolling content with the actions pinned
/// to the bottom so the main button is always under the thumb.
class _StepFrame extends StatelessWidget {
  const _StepFrame({required this.content, required this.actions});

  final List<Widget> content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions,
          ),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: tk.primarySoft,
        borderRadius: BorderRadius.circular(TkRadius.card),
      ),
      child: Icon(icon, size: 32, color: tk.primary),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return _StepFrame(
      content: <Widget>[
        const TkLogo(size: 64),
        const SizedBox(height: 32),
        Text('Teman perjalanan KRL setiap hari', style: textTheme.displayLarge),
        const SizedBox(height: 12),
        Text(
          'Cek jadwal, ikuti perjalanan stasiun demi stasiun, dan dapat '
          'pengingat sebelum tujuan.',
          style: textTheme.bodyLarge?.copyWith(color: tk.textMuted),
        ),
        const SizedBox(height: 28),
        const TkRowGroup(
          children: <Widget>[
            TkRow(
              icon: Icons.schedule_rounded,
              title: 'Jadwal dari stasiun terdekat',
              subtitle: 'Lihat keberangkatan berikutnya tanpa mengetik.',
            ),
            TkRow(
              icon: Icons.route_rounded,
              title: 'Ikuti perjalananmu',
              subtitle:
                  'Tahu stasiun berikutnya dan sisa stasiun sampai tujuan.',
            ),
            TkRow(
              icon: Icons.notifications_active_outlined,
              title: 'Pengingat sebelum turun',
              subtitle:
                  'Notifikasi tiga, dua, dan satu stasiun sebelum tujuan.',
            ),
          ],
        ),
      ],
      actions: <Widget>[
        SizedBox(
          height: 56,
          child: FilledButton(onPressed: onNext, child: const Text('Mulai')),
        ),
      ],
    );
  }
}

class _BenefitList extends StatelessWidget {
  const _BenefitList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      children: <Widget>[
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.check_circle_rounded, size: 22, color: tk.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LocationStep extends StatelessWidget {
  const _LocationStep({required this.onRequest, required this.onSkip});

  final Future<void> Function() onRequest;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return _StepFrame(
      content: <Widget>[
        const _IconTile(icon: Icons.location_on_outlined),
        const SizedBox(height: 24),
        Text('Lokasi, secara bertahap', style: textTheme.headlineLarge),
        const SizedBox(height: 12),
        Text(
          'Lokasi membantu menemukan stasiun dan memberi peringatan '
          'perjalanan. Pelacakan intensif hanya berjalan setelah kamu memulai '
          'perjalanan.',
          style: textTheme.bodyLarge?.copyWith(color: tk.textMuted),
        ),
        const SizedBox(height: 24),
        const _BenefitList(
          items: <String>[
            'Temukan stasiun terdekat',
            'Deteksi perjalanan setelah disetujui',
            'Peringatan sebelum stasiun tujuan',
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Bisa diubah kapan saja di Profil.',
          style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
        ),
      ],
      actions: <Widget>[
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: onRequest,
            child: const Text('Aktifkan saat digunakan'),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Lewati sekarang'),
        ),
      ],
    );
  }
}

class _RemindersStep extends StatefulWidget {
  const _RemindersStep({
    required this.onRequestNotifications,
    required this.onRequestBattery,
    required this.onNext,
  });

  final Future<bool> Function() onRequestNotifications;
  final Future<bool> Function() onRequestBattery;
  final VoidCallback onNext;

  @override
  State<_RemindersStep> createState() => _RemindersStepState();
}

enum _AskState { idle, allowed, notAllowed }

class _RemindersStepState extends State<_RemindersStep> {
  _AskState _notifications = _AskState.idle;
  _AskState _battery = _AskState.idle;

  bool get _anyAsked =>
      _notifications != _AskState.idle || _battery != _AskState.idle;

  Future<void> _askNotifications() async {
    final granted = await widget.onRequestNotifications();
    if (mounted) {
      setState(
        () =>
            _notifications = granted ? _AskState.allowed : _AskState.notAllowed,
      );
    }
  }

  Future<void> _askBattery() async {
    final ignored = await widget.onRequestBattery();
    if (mounted) {
      setState(
        () => _battery = ignored ? _AskState.allowed : _AskState.notAllowed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return _StepFrame(
      content: <Widget>[
        const _IconTile(icon: Icons.notifications_none_rounded),
        const SizedBox(height: 24),
        Text('Peringatan yang bisa diatur', style: textTheme.headlineLarge),
        const SizedBox(height: 12),
        Text(
          'Notifikasi membantu saat aplikasi diminimalkan. Kamu dapat memilih '
          'suara, getaran, atau mode senyap nanti.',
          style: textTheme.bodyLarge?.copyWith(color: tk.textMuted),
        ),
        const SizedBox(height: 24),
        _PermissionCard(
          icon: Icons.notifications_active_outlined,
          title: 'Notifikasi stasiun',
          description:
              'Tiga, dua, dan satu stasiun sebelum tujuan, lalu waktunya '
              'transit atau turun.',
          actionLabel: 'Aktifkan notifikasi',
          state: _notifications,
          onAction: _askNotifications,
        ),
        const SizedBox(height: 12),
        _PermissionCard(
          icon: Icons.battery_charging_full_rounded,
          title: 'Tetap berjalan di latar belakang',
          description:
              'Sebagian HP menghentikan aplikasi yang tidak dibuka, sehingga '
              'pengingat bisa terlambat. Izin ini mencegahnya selama '
              'perjalanan.',
          actionLabel: 'Izinkan di latar belakang',
          state: _battery,
          onAction: _askBattery,
          deniedLabel: 'Sudah diminta',
        ),
      ],
      actions: <Widget>[
        if (_anyAsked)
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: widget.onNext,
              child: const Text('Lanjut'),
            ),
          )
        else
          TextButton(
            onPressed: widget.onNext,
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: const Text('Lewati sekarang'),
          ),
      ],
    );
  }
}

class _PermissionCard extends StatefulWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.state,
    required this.onAction,
    this.deniedLabel = 'Belum diizinkan',
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final _AskState state;
  final Future<void> Function() onAction;
  final String deniedLabel;

  @override
  State<_PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends State<_PermissionCard> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onAction();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(widget.icon, color: tk.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.title, style: textTheme.titleSmall)),
              if (widget.state == _AskState.allowed)
                const TkPill(
                  label: 'Diizinkan',
                  icon: Icons.check_rounded,
                  tone: TkPillTone.success,
                  dense: true,
                )
              else if (widget.state == _AskState.notAllowed)
                TkPill(
                  label: widget.deniedLabel,
                  tone: TkPillTone.warning,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.description,
            style: textTheme.bodyMedium?.copyWith(color: tk.textMuted),
          ),
          if (widget.state != _AskState.allowed) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.tonal(
                onPressed: _busy ? null : _run,
                child: Text(widget.actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyRouteStep extends ConsumerWidget {
  const _DailyRouteStep({
    required this.homeStation,
    required this.workStation,
    required this.onHomeChanged,
    required this.onWorkChanged,
    required this.onFinish,
  });

  final String? homeStation;
  final String? workStation;
  final ValueChanged<String?> onHomeChanged;
  final ValueChanged<String?> onWorkChanged;
  final Future<void> Function() onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final stationsAsync = ref.watch(stationListProvider);
    final stations = List<Station>.of(
      stationsAsync.asData?.value ?? const <Station>[],
    )..sort((a, b) => a.name.compareTo(b.name));
    String? nameOf(String? id) =>
        stations.where((s) => s.id == id).firstOrNull?.name;
    return _StepFrame(
      content: <Widget>[
        const _IconTile(icon: Icons.route_rounded),
        const SizedBox(height: 24),
        Text('Simpan rute harian', style: textTheme.headlineLarge),
        const SizedBox(height: 12),
        Text(
          'Opsional. Rute ini hanya disimpan di perangkat pada mode lokal.',
          style: textTheme.bodyLarge?.copyWith(color: tk.textMuted),
        ),
        const SizedBox(height: 24),
        if (stationsAsync.isLoading)
          const Column(
            children: <Widget>[
              TkSkeleton(height: 64, radius: 14),
              SizedBox(height: 12),
              TkSkeleton(height: 64, radius: 14),
            ],
          )
        else ...<Widget>[
          _StationChoice(
            label: 'Stasiun rumah',
            icon: Icons.home_outlined,
            value: nameOf(homeStation),
            onPick: () async {
              final id = await showStationPicker(
                context,
                stations: stations,
                title: 'Stasiun rumah',
                selectedId: homeStation,
              );
              if (id != null) {
                onHomeChanged(id);
              }
            },
            onClear: homeStation == null ? null : () => onHomeChanged(null),
          ),
          const SizedBox(height: 12),
          _StationChoice(
            label: 'Stasiun kantor atau kampus',
            icon: Icons.work_outline_rounded,
            value: nameOf(workStation),
            onPick: () async {
              final id = await showStationPicker(
                context,
                stations: stations,
                title: 'Stasiun kantor atau kampus',
                selectedId: workStation,
              );
              if (id != null) {
                onWorkChanged(id);
              }
            },
            onClear: workStation == null ? null : () => onWorkChanged(null),
          ),
          if (stationsAsync.hasError || stations.isEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Daftar stasiun belum tersedia. Kamu bisa mengatur rute harian '
              'nanti di Profil.',
              style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
            ),
          ],
        ],
      ],
      actions: <Widget>[
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: onFinish,
            child: const Text('Buka Teman Kereta'),
          ),
        ),
      ],
    );
  }
}

class _StationChoice extends StatelessWidget {
  const _StationChoice({
    required this.label,
    required this.icon,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final IconData icon;
  final String? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return TkCard(
      onTap: onPick,
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      semanticLabel:
          '$label: ${value ?? 'belum dipilih'}. Ketuk untuk memilih.',
      child: ExcludeSemantics(
        child: Row(
          children: <Widget>[
            Icon(icon, color: tk.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                  ),
                  Text(
                    value ?? 'Pilih stasiun',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color: value == null ? tk.textMuted : tk.text,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                tooltip: 'Hapus pilihan $label',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              )
            else
              const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.unfold_more_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
