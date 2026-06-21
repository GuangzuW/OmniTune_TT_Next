import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimens.dart';
import 'package:app/features/shared/track_artwork.dart';
import 'package:app/state/player_controller.dart';

/// Persistent bar above the nav. Tapping opens the full Now Playing screen.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final track = player.current;
    if (track == null) return const SizedBox.shrink();

    final progress = player.duration > 0 ? (player.position / player.duration).clamp(0.0, 1.0) : 0.0;

    return Material(
      color: AppColors.sidebar,
      child: InkWell(
        onTap: () => context.push('/now-playing'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: AppColors.divider,
              color: AppColors.coral,
            ),
            SizedBox(
              height: AppDimens.miniPlayerHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                child: Row(
                  children: [
                    TrackArtwork(track: track, size: 48),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (track.artist.isNotEmpty)
                            Text(track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed: controller.prev,
                    ),
                    _PlayButton(
                      playing: player.isPlaying,
                      buffering: player.buffering,
                      onTap: controller.togglePlay,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: () => controller.next(),
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
}

class _PlayButton extends StatelessWidget {
  final bool playing;
  final bool buffering;
  final VoidCallback onTap;
  const _PlayButton({required this.playing, required this.buffering, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle),
        child: buffering
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
      ),
    );
  }
}
