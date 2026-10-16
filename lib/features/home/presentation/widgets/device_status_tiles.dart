import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/network/device_status.dart';
import '../../../../core/network/gps_status_controller.dart';
import '../../../../core/network/internet_status_controller.dart';
import '../../../stations/presentation/nearest_station_controller.dart';

/// "Status perangkat": a compact strip showing how good the internet is
/// (measured round trip) and whether GPS is usable. It is deliberately small
/// and sits at the very bottom of Home so it never competes with the next
/// train. Color is never the only signal: every state also has an icon and a
/// word.
class DeviceStatusTiles extends ConsumerWidget {
  const DeviceStatusTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final internet = ref.watch(internetStatusProvider);
    final gps = ref.watch(gpsStatusProvider);
    final tk = context.tk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Status perangkat',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: tk.textMuted),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _internetChip(
              internet,
              () => ref.read(internetStatusProvider.notifier).refresh(),
            ),
            _gpsChip(gps.level, () => _gpsAction(context, ref, gps.level)),
          ],
        ),
      ],
    );
  }

  Future<void> _gpsAction(
    BuildContext context,
    WidgetRef ref,
    GpsLevel? level,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (level) {
      case GpsLevel.servicesOff:
        await Geolocator.openLocationSettings();
      case GpsLevel.permissionBlocked:
        await Geolocator.openAppSettings();
      case GpsLevel.permissionDenied:
        // The chip wording says why location is needed, which is the
        // explanation PRD section 10 asks for before the system dialog.
        final granted = await ref
            .read(nearestStationControllerProvider.notifier)
            .requestPermissionAndRefresh();
        if (!granted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Izin lokasi belum diberikan.')),
          );
        }
      case GpsLevel.ready:
      case null:
        break;
    }
    await ref.read(gpsStatusProvider.notifier).refresh();
  }

  Widget _internetChip(InternetStatus status, VoidCallback onRefresh) {
    final level = status.level;
    final (icon, tone) = switch (level) {
      LatencyLevel.good => (Icons.wifi_rounded, _ChipTone.good),
      LatencyLevel.slow => (Icons.network_wifi_2_bar_rounded, _ChipTone.warn),
      LatencyLevel.bad => (Icons.network_wifi_1_bar_rounded, _ChipTone.bad),
      LatencyLevel.offline => (Icons.wifi_off_rounded, _ChipTone.bad),
      null => (Icons.wifi_rounded, _ChipTone.idle),
    };
    final value = switch (level) {
      null => 'Mengukur',
      LatencyLevel.offline => 'Offline',
      _ => formatLatency(status.latencyMs),
    };
    final word = level == null || level == LatencyLevel.offline
        ? null
        : latencyLabel(level);
    final ms = status.latencyMs;
    return _StatusChip(
      icon: icon,
      tone: tone,
      value: value,
      word: word,
      onTap: onRefresh,
      semanticLabel: level == null
          ? 'Internet, sedang diukur. Ketuk untuk ukur ulang.'
          : 'Internet, ${word ?? value}'
                '${ms == null ? '' : ', $ms milidetik'}.'
                ' Ketuk untuk ukur ulang.',
    );
  }

  Widget _gpsChip(GpsLevel? level, VoidCallback onAction) {
    final (icon, tone, value, action) = switch (level) {
      GpsLevel.ready => (
        Icons.location_on_rounded,
        _ChipTone.good,
        'GPS nyala',
        null,
      ),
      GpsLevel.servicesOff => (
        Icons.location_off_rounded,
        _ChipTone.bad,
        'GPS mati',
        'Buka pengaturan',
      ),
      GpsLevel.permissionDenied => (
        Icons.location_disabled_rounded,
        _ChipTone.warn,
        'GPS tanpa izin',
        'Izinkan lokasi',
      ),
      GpsLevel.permissionBlocked => (
        Icons.location_disabled_rounded,
        _ChipTone.bad,
        'GPS ditolak',
        'Buka pengaturan',
      ),
      null => (
        Icons.location_searching_rounded,
        _ChipTone.idle,
        'GPS diperiksa',
        null,
      ),
    };
    return _StatusChip(
      icon: icon,
      tone: tone,
      value: value,
      word: action,
      emphasizeWord: action != null,
      onTap: action == null ? null : onAction,
      semanticLabel: action == null ? value : '$value. $action.',
    );
  }
}

enum _ChipTone { good, warn, bad, idle }

/// One small status: icon, short value, and an optional word (the latency
/// verdict, or the action when something needs attention). 44dp tall.
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.tone,
    required this.value,
    required this.semanticLabel,
    this.word,
    this.emphasizeWord = false,
    this.onTap,
  });

  final IconData icon;
  final _ChipTone tone;
  final String value;
  final String? word;
  final bool emphasizeWord;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final toneColor = switch (tone) {
      _ChipTone.good => tk.success,
      _ChipTone.warn => tk.warning,
      _ChipTone.bad => tk.danger,
      _ChipTone.idle => tk.textMuted,
    };
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: tk.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TkRadius.control),
          side: BorderSide(color: tk.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 18, color: toneColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(
                        fontFeatures: AppTheme.timeFeatures,
                      ),
                    ),
                  ),
                  if (word != null) ...<Widget>[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        word!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium?.copyWith(
                          color: emphasizeWord ? tk.primary : toneColor,
                          fontWeight: FontWeight.w700,
                          decoration: emphasizeWord
                              ? TextDecoration.underline
                              : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
