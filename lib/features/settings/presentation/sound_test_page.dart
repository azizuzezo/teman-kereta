import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/notifications/alert_audio_plan.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/platform/native_trip_service.dart';
import '../../../core/widgets/tk_components.dart';
import 'settings_controller.dart';
import 'widgets/settings_rows.dart';

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

class _SoundTestPageState extends ConsumerState<SoundTestPage>
    with WidgetsBindingObserver {
  String? _playing;
  AudioRouteInfo _route = AudioRouteInfo.speaker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshRoute());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A headset is often plugged in while the rider is in another app.
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshRoute());
    }
  }

  Future<void> _refreshRoute() async {
    final route = await ref.read(nativeTripServiceProvider).audioRoute();
    if (mounted) {
      setState(() => _route = route);
    }
  }

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
    final tk = context.tk;

    final native = ref.read(nativeTripServiceProvider);
    // The announcement and the bell tested on their own, so a rider can tell
    // which of the two is missing instead of guessing from a whole alert.
    final audioEntries = <_SoundTestEntry>[
      _SoundTestEntry(
        key: 'audio_voice',
        title: 'Suara pengumuman saja',
        subtitle: '"Satu stasiun lagi", tanpa bell.',
        icon: Icons.record_voice_over_rounded,
        play: () => native.playAlertAudio(voice: 'remaining_station_1'),
      ),
      _SoundTestEntry(
        key: 'audio_transit',
        title: 'Suara pengumuman transit',
        subtitle: '"Satu stasiun lagi menuju transit", tanpa bell.',
        icon: Icons.swap_calls_rounded,
        play: () => native.playAlertAudio(voice: 'remaining_transit_1'),
      ),
      _SoundTestEntry(
        key: 'audio_bell',
        title: 'Bell saja',
        subtitle: 'Nada bell yang menyusul pengumuman terakhir.',
        icon: Icons.notifications_active_rounded,
        play: () => native.playAlertAudio(bell: true),
      ),
      _SoundTestEntry(
        key: 'audio_both',
        title: 'Pengumuman lalu bell',
        subtitle: 'Bell mulai setelah pengumuman selesai penuh.',
        icon: Icons.queue_music_rounded,
        play: () =>
            native.playAlertAudio(voice: 'remaining_station_1', bell: true),
      ),
    ];

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
      for (final minutes in intercityReminderMinutes)
        _SoundTestEntry(
          key: 'intercity_$minutes',
          title: 'Antar kota: $minutes menit lagi',
          subtitle: bellFollowsIntercityVoice(minutes)
              ? 'Pengingat terakhir kereta antar kota, disusul bell.'
              : 'Pengingat kereta antar kota.',
          icon: Icons.train_rounded,
          play: () => notifications.showIntercityEtaAlert(
            minutes: minutes,
            destination: 'Bandung',
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
            const SettingsIntro(
              'Ketuk salah satu untuk memainkan peringatan aslinya, lengkap '
              'dengan nada, getaran, dan suara pengumumannya. Pastikan volume '
              'notifikasi perangkat tidak dalam mode senyap.',
            ),
            if (!settings.soundEnabled) ...<Widget>[
              TkCard(
                tone: TkCardTone.warning,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.volume_off_rounded, color: tk.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Suara notifikasi sedang dimatikan',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tes di bawah tetap berbunyi, tapi peringatan '
                                'saat perjalanan asli tidak akan bersuara '
                                'sampai kamu menyalakannya lagi.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => ref
                            .read(settingsControllerProvider.notifier)
                            .setSoundEnabled(true),
                        child: const Text('Nyalakan suara'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TkRowGroup(
              children: <Widget>[
                TkRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Tidak terdengar apa pun?',
                  subtitle:
                      'Izin notifikasi mungkin belum aktif. Ketuk untuk '
                      'memintanya.',
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
              ],
            ),
            const SizedBox(height: 20),
            const TkSectionLabel('Suara dan bell'),
            TkCard(
              tone: _route.isHeadset ? TkCardTone.soft : TkCardTone.surface,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Icon(
                    _route.isHeadset
                        ? Icons.headphones_rounded
                        : Icons.volume_up_rounded,
                    color: tk.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _route.statusText,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          _route.isHeadset
                              ? 'Pengumuman dan bell hanya bunyi di headset.'
                              : 'Pasang headset dan bell hanya bunyi di '
                                    'headset, tidak di speaker.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Periksa lagi',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => unawaited(_refreshRoute()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TkRowGroup(
              children: <Widget>[
                for (final entry in audioEntries)
                  TkRow(
                    icon: entry.icon,
                    title: entry.title,
                    subtitle: entry.subtitle,
                    onTap: _playing != null
                        ? null
                        : () => _play(entry.key, entry.play),
                    trailing: _playing == entry.key
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.play_circle_outline_rounded,
                            color: tk.primary,
                            semanticLabel: 'Putar',
                          ),
                  ),
                TkRow(
                  icon: Icons.stop_circle_outlined,
                  title: 'Hentikan suara',
                  subtitle: 'Bell berbunyi sampai dihentikan, seperti saat '
                      'perjalanan asli.',
                  onTap: () => ref
                      .read(nativeTripServiceProvider)
                      .stopAlertAudio(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const TkSectionLabel('Pilih peringatan'),
            TkRowGroup(
              children: <Widget>[
                for (final entry in entries)
                  TkRow(
                    icon: entry.icon,
                    title: entry.title,
                    subtitle: entry.subtitle,
                    onTap: _playing != null
                        ? null
                        : () => _play(entry.key, entry.play),
                    trailing: _playing == entry.key
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.play_circle_outline_rounded,
                            color: tk.primary,
                            semanticLabel: 'Putar',
                          ),
                  ),
              ],
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
