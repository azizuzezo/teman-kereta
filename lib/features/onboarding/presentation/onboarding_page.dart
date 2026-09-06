import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/preferences/preferences_store.dart';
import '../../../core/widgets/tk_logo.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../settings/presentation/settings_controller.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const TkLogo(size: 36),
        actions: <Widget>[
          if (_page > 0)
            TextButton(onPressed: _finish, child: const Text('Lewati')),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Row(
                children: List<Widget>.generate(4, (index) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      height: 4,
                      margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                      decoration: BoxDecoration(
                        color: index <= _page
                            ? AppColors.blue
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (value) => setState(() => _page = value),
                children: <Widget>[
                  _WelcomeStep(onNext: _next),
                  _PermissionStep(
                    icon: Icons.location_on_outlined,
                    title: 'Lokasi, secara bertahap',
                    description:
                        'Lokasi membantu menemukan stasiun dan memberi peringatan perjalanan. Pelacakan intensif hanya berjalan setelah kamu memulai perjalanan.',
                    items: const <String>[
                      'Temukan stasiun terdekat',
                      'Deteksi perjalanan setelah disetujui',
                      'Peringatan sebelum stasiun tujuan',
                    ],
                    primaryLabel: 'Aktifkan saat digunakan',
                    onPrimary: _requestLocation,
                    onSkip: _next,
                  ),
                  _PermissionStep(
                    icon: Icons.notifications_none_rounded,
                    title: 'Peringatan yang bisa diatur',
                    description:
                        'Notifikasi membantu saat aplikasi diminimalkan. Kamu dapat memilih suara, getaran, atau mode senyap nanti.',
                    items: const <String>[
                      'Tiga, dua, dan satu stasiun sebelum tujuan',
                      'Waktunya transit atau turun',
                      'Perubahan jadwal saat sumber resmi tersedia',
                    ],
                    primaryLabel: 'Aktifkan notifikasi',
                    onPrimary: _requestNotifications,
                    onSkip: _next,
                  ),
                  _DailyRouteStep(
                    homeStation: _homeStation,
                    workStation: _workStation,
                    onHomeChanged: (value) => setState(() => _homeStation = value),
                    onWorkChanged: (value) => setState(() => _workStation = value),
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
    if (_page >= 3) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(_page + 1);
    } else {
      _controller.nextPage(
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

  Future<void> _requestNotifications() async {
    final granted = await ref
        .read(localNotificationServiceProvider)
        .requestPermission();
    if (mounted && !granted) {
      _showMessage(
        'Notifikasi belum diizinkan. Kamu dapat mengaktifkannya dari Profil.',
      );
    }
    _next();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            label: 'Ilustrasi kereta dan jalur perjalanan',
            image: true,
            child: Container(
              height: 210,
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: <Widget>[
                  const Positioned(
                    left: 28,
                    right: 28,
                    top: 102,
                    child: Divider(color: AppColors.softBlue, thickness: 5),
                  ),
                  for (final left in <double>[36, 112, 188, 264])
                    Positioned(
                      left: left,
                      top: 92,
                      child: const CircleAvatar(
                        radius: 11,
                        backgroundColor: AppColors.surfaceLight,
                      ),
                    ),
                  const Positioned(
                    left: 96,
                    top: 42,
                    child: Icon(
                      Icons.train_rounded,
                      size: 88,
                      color: AppColors.coral,
                    ),
                  ),
                  const Positioned(
                    left: 28,
                    bottom: 24,
                    child: Text(
                      'Cari • Naik • Diingatkan',
                      style: TextStyle(
                        color: AppColors.surfaceLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Teman perjalanan KRL setiap hari',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Rencanakan perjalanan, ikuti stasiun, dan dapatkan pengingat sebelum tujuan tanpa harus membuat akun.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNext,
              child: const Text('Mulai'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionStep extends StatelessWidget {
  const _PermissionStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.items,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSkip,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> items;
  final String primaryLabel;
  final Future<void> Function() onPrimary;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 36),
          ),
          const SizedBox(height: 28),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.check_circle_outline, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimary,
              child: Text(primaryLabel),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onSkip,
              child: const Text('Lewati sekarang'),
            ),
          ),
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
    final stations = List<Station>.of(
      ref.watch(stationListProvider).asData?.value ?? const <Station>[],
    )..sort((a, b) => a.name.compareTo(b.name));
    final stationItems = <DropdownMenuItem<String>>[
      for (final station in stations)
        DropdownMenuItem(
          value: station.id,
          child: Text(station.name, overflow: TextOverflow.ellipsis),
        ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.route_rounded, size: 64, color: AppColors.blue),
          const SizedBox(height: 24),
          Text('Simpan rute harian', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text(
            'Opsional. Rute ini hanya disimpan di perangkat pada mode lokal.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          DropdownButtonFormField<String>(
            initialValue: homeStation,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Stasiun rumah',
              prefixIcon: Icon(Icons.home_outlined),
            ),
            items: stationItems,
            onChanged: onHomeChanged,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: workStation,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Stasiun kantor atau kampus',
              prefixIcon: Icon(Icons.work_outline_rounded),
            ),
            items: stationItems,
            onChanged: onWorkChanged,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onFinish,
              child: const Text('Buka Teman Kereta'),
            ),
          ),
        ],
      ),
    );
  }
}
