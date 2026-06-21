import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimens.dart';
import 'package:app/state/player_controller.dart';

class EqualizerSheet extends ConsumerWidget {
  const EqualizerSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
        ),
        builder: (_) => const EqualizerSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final presetValue = kEqPresets.containsKey(player.eqPreset) ? player.eqPreset : 'Custom';

    return Padding(
      padding: const EdgeInsets.all(AppDimens.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Equalizer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              DropdownButton<String>(
                value: presetValue,
                dropdownColor: AppColors.card,
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.w600),
                items: [
                  ...kEqPresets.keys,
                  if (!kEqPresets.containsKey(player.eqPreset)) 'Custom',
                ].map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (v) {
                  if (v != null && kEqPresets.containsKey(v)) controller.applyEqPreset(v);
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimens.lg),
          SizedBox(
            height: 220,
            child: Row(
              children: List.generate(kEqFreqs.length, (i) {
                final freq = kEqFreqs[i];
                return Expanded(
                  child: Column(
                    children: [
                      Text(player.eqGains[i].toStringAsFixed(0),
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value: player.eqGains[i].clamp(-12.0, 12.0),
                            min: -12,
                            max: 12,
                            onChanged: (v) => controller.setEqBand(i, v),
                          ),
                        ),
                      ),
                      Text(freq < 1000 ? '$freq' : '${freq ~/ 1000}k',
                          style: const TextStyle(color: AppColors.sky, fontSize: 10)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
