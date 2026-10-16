import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/ride_detection.dart';
import '../../../domain/entities/transit_models.dart';
import 'ride_detection_controller.dart';

class RideDetectionConfirmPage extends ConsumerWidget {
  const RideDetectionConfirmPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final assessment = ref.watch(rideDetectionControllerProvider)?.assessment;
    final controller = ref.read(rideDetectionControllerProvider.notifier);

    if (assessment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Konfirmasi deteksi naik KRL')),
        body: AppEmptyState(
          icon: Icons.sensors_off_outlined,
          title: 'Tidak ada deteksi yang menunggu',
          message: 'Prompt ini sudah selesai diproses atau kedaluwarsa.',
          action: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Kembali ke beranda'),
          ),
        ),
      );
    }

    final stations = ref.watch(stationListProvider).value ?? const <Station>[];
    final stationName = _stationName(assessment.stationId, stations);
    final destinationName = assessment.suggestedDestinationId == null
        ? null
        : _stationName(assessment.suggestedDestinationId!, stations);
    final isStrong = assessment.level == RideDetectionLevel.strong;

    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi deteksi naik KRL')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isStrong ? tk.successSoft : tk.primarySoft,
                      borderRadius: BorderRadius.circular(TkRadius.control),
                    ),
                    child: Icon(
                      Icons.train_rounded,
                      size: 30,
                      color: isStrong ? tk.success : tk.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isStrong && destinationName != null
                        ? 'Sepertinya kamu sedang berada di Commuter Line menuju $destinationName.'
                        : 'Sepertinya kamu baru saja meninggalkan Stasiun $stationName.',
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isStrong
                        ? 'Mulai panduan perjalanan?'
                        : 'Apakah kamu sedang naik kereta?',
                    style: textTheme.bodyLarge?.copyWith(color: tk.textMuted),
                  ),
                  if (isStrong && destinationName != null) ...<Widget>[
                    const SizedBox(height: 16),
                    TkCard(
                      tone: TkCardTone.soft,
                      child: Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              stationName,
                              style: textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: tk.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              destinationName,
                              style: textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (assessment.reasons.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 20),
                    TkSectionLabel('Kenapa kami menduga begini'),
                    TkCard(
                      tone: TkCardTone.alt,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final reason in assessment.reasons)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: tk.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      reason,
                                      style: textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: tk.bg,
                border: Border(top: BorderSide(color: tk.border)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (destinationName != null)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: () async {
                            await controller.confirmStart();
                            if (context.mounted) {
                              context.go('/active-trip');
                            }
                          },
                          child: const Text('Ya, mulai'),
                        ),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          controller.chooseAnother();
                          context.go('/schedule/search');
                        },
                        child: const Text('Pilih kereta lain'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              controller.dismiss();
                              context.go('/');
                            },
                            child: const Text('Bukan'),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              await controller.dismissForToday();
                              if (context.mounted) {
                                context.go('/');
                              }
                            },
                            child: const Text(
                              'Jangan tanya lagi hari ini',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stationName(String id, List<Station> stations) {
    return stations.where((s) => s.id == id).firstOrNull?.name ??
        demoStations.where((s) => s.id == id).firstOrNull?.name ??
        id;
  }
}
