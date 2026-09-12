import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/local_notification_service.dart';
import 'settings_controller.dart';

/// "Tes suara peringatan" — plays each trip alert exactly as it will sound
/// during a real trip, so a rider can find out whether they'll actually
/// hear their stop *before* they're relying on it.
///
/// Deliberately fires the real notification (custom `raw/*.wav` channel
/// sound, vibration, and the spoken Indonesian announcement) rather than
/// playing the asset through an audio player: the thing worth testing is
/// the whole path — the notification channel, its sound, whether the phone
/// is on silent, whether permission was ever granted — not the waveform.
/// The one difference from a real alert is that previews are not written to
/// "Pusat notifikasi" (see `LocalNotificationService`'s `log` flag).
class SoundTestPage extends ConsumerStatefulWidget {
  const SoundTestPage({super.key});

  @override
  ConsumerState<SoundTestPage> createState() => _SoundTestPageState();
}

class _SoundTestPageState extends ConsumerState<SoundTestPage> {
  String? _playing;

  Future<void> _play(String key, Future<void> Function() alert) async {
    setState(() => _playing = key);
    try {
      await alert();
    } finally {
      if (mounted) setState(() => _playing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final notifications = ref.read(localNotificationServiceProvider);
    // Previews always play with sound on: a silent "test" tells the rider
    // nothing. The banner below explains that their own setting is off.
    final vibrate = settings.vibrationEnabled;

    final entries = <_SoundTestEntry>[
      _SoundTestEntry(
        key: 'stop_3',
        title: '3 stasiun lagi menuju tujuan',
        subtitle: 'Nada hitung mundur pertama.',
        icon: Icons.filter_3_rounded,
        play: () => notifications.showStopAlert(
          remainingStops: 3,
          destination: 'Bogor',
          isDemo: false,
          vibrate: vibrate,
          log: false,
        ),
      ),
      _SoundTestEntry(
        key: 'stop_2',
        title: '2 stasiun lagi menuju tujuan',
        subtitle: 'Nada hitung mundur kedua.',
        icon: Icons.filter_2_rounded,
        play: () => notifications.showStopAlert(
          remainingStops: 2,
          destination: 'Bogor',
          isDemo: false,
          vibrate: vibrate,
          log: false,
        ),
      ),
      _SoundTestEntry(
        key: 'stop_1',
        title: '1 stasiun lagi menuju tujuan',
        subtitle: 'Peringatan terakhir sebelum bersiap turun.',
        icon: Icons.filter_1_rounded,
        play: () => notifications.showStopAlert(
          remainingStops: 1,
          destination: 'Bogor',
          isDemo: false,
          vibrate: vibrate,
          log: false,
        ),
      ),
      _SoundTestEntry(
        key: 'arrive',
        title: 'Tiba di tujuan',
        subtitle: 'Nada saat kereta sampai di stasiun tujuanmu.',
        icon: Icons.flag_rounded,
        play: () => notifications.showStopAlert(
          remainingStops: 0,
          destination: 'Bogor',
          isDemo: false,
          vibrate: vibrate,
          log: false,
        ),
      ),
      _SoundTestEntry(
        key: 'transit_3',
        title: '3 stasiun lagi menuju transit',
        subtitle: 'Hitung mundur khusus perjalanan yang perlu ganti kereta.',
        icon: Icons.swap_calls_rounded,
        play: () => notifications.showTransferApproachingAlert(
          remainingStops: 3,
          stationName: 'Manggarai',
          isDemo: false,
          vibrate: vibrate,
          log: false,
        ),
      ),
      _SoundTestEntry(
        key: 'transit_2',
        title: '2 stasiun lagi menuju transit',
        subtitle: 'Hitung mundur khusus perjalanan yang perlu ganti kereta.',
        icon: Icons.swap_calls_rounded,
        play: () => notifications.showTransferApproachingAlert(
          remainingStops: 2,
          stationName: 'Manggarai',
          isDemo: false,
          vibrate: vibrate,
          log: false,
        ),
      ),
      _SoundTestEntry(
        key: 'transit_1',
        title: '1 stasiun lagi menuju transit',
        subtitle: 'Peringatan terakhir sebelum bersiap transit.',
        icon: Icons.swap_calls_rounded,
        play: () => notifications.showTransferApproachingAlert(
          remainingStops: 1,
          stationName: 'Manggarai',
          isDemo: false,
          vibrate: vibrate,
          log: false,
        ),
      ),
      _SoundTestEntry(
        key: 'transit_now',
        title: 'Saatnya transit',
        subtitle: 'Nada saat kamu harus turun dan pindah kereta.',
        icon: Icons.transfer_within_a_station_rounded,
        play: () => notifications.showTransferAlert(
          stationName: 'Manggarai',
          instruction: null,
          isDemo: false,
          vibrate: vibrate,
          log: false,
        ),
      ),
      _SoundTestEntry(
        key: 'missed',
        title: 'Tujuan terlewat',
        subtitle: 'Peringatan darurat kalau kamu kelewatan stasiun tujuan.',
        icon: Icons.warning_amber_rounded,
        play: () => notifications.showMissedDestinationAlert(
          destination: 'Bogor',
          isDemo: false,
          vibrate: vibrate,
          log: false,
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Tes suara peringatan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            const Text(
              'Ketuk salah satu untuk memainkan peringatan aslinya — lengkap '
              'dengan nada, getaran, dan suara pengumumannya. Pastikan volume '
              'notifikasi perangkat tidak dalam mode senyap.',
            ),
            if (!settings.soundEnabled) ...<Widget>[
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.volume_off_rounded),
                  title: const Text('Suara notifikasi sedang dimatikan'),
                  subtitle: const Text(
                    'Tes di bawah tetap berbunyi, tapi peringatan saat '
                    'perjalanan asli tidak akan bersuara sampai kamu '
                    'menyalakannya lagi.',
                  ),
                  trailing: TextButton(
                    onPressed: () => ref
                        .read(settingsControllerProvider.notifier)
                        .setSoundEnabled(true),
                    child: const Text('Nyalakan'),
                  ),
                  isThreeLine: true,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Tidak terdengar apa pun?'),
                subtitle: const Text(
                  'Izin notifikasi mungkin belum aktif. Ketuk untuk memintanya.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final granted = await notifications.requestPermission();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        granted
                            ? 'Izin notifikasi aktif.'
                            : 'Izin notifikasi masih ditolak. Aktifkan lewat '
                                'pengaturan Android.',
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: <Widget>[
                  for (var index = 0; index < entries.length; index += 1) ...<Widget>[
                    if (index > 0) const Divider(height: 1),
                    ListTile(
                      leading: Icon(entries[index].icon),
                      title: Text(entries[index].title),
                      subtitle: Text(entries[index].subtitle),
                      trailing: _playing == entries[index].key
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_circle_outline_rounded),
                      onTap: _playing != null
                          ? null
                          : () => _play(entries[index].key, entries[index].play),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundTestEntry {
  const _SoundTestEntry({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.play,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Future<void> Function() play;
}
