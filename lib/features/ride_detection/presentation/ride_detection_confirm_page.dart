import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/ride_detection.dart';
import '../../../domain/entities/transit_models.dart';
import 'ride_detection_controller.dart';

class RideDetectionConfirmPage extends ConsumerWidget {
  const RideDetectionConfirmPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.train_rounded,
                size: 44,
                color: isStrong ? AppColors.success : AppColors.blue,
              ),
              const SizedBox(height: 16),
              Text(
                isStrong && destinationName != null
                    ? 'Sepertinya kamu sedang berada di Commuter Line menuju $destinationName.'
                    : 'Sepertinya kamu baru saja meninggalkan Stasiun $stationName.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                isStrong
                    ? 'Mulai panduan perjalanan?'
                    : 'Apakah kamu sedang naik kereta?',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (assessment.reasons.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                for (final reason in assessment.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.circle, size: 6),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reason,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const Spacer(),
              if (destinationName != null)
                SizedBox(
                  width: double.infinity,
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
                child: OutlinedButton(
                  onPressed: () {
                    controller.chooseAnother();
                    context.go('/schedule/search');
                  },
                  child: const Text('Pilih kereta lain'),
                ),
              ),
              const SizedBox(height: 10),
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
                      child: const Text('Jangan tanya lagi hari ini'),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
