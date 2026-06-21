import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/features/shared/track_artwork.dart';
import 'package:app/state/player_controller.dart';

/// Reorderable "Up Next" queue.
class QueueView extends ConsumerWidget {
  const QueueView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    if (player.queue.isEmpty) {
      return const Center(
          child: Text('Queue is empty', style: TextStyle(color: AppColors.textTertiary)));
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: player.queue.length,
      onReorder: controller.reorder,
      itemBuilder: (context, i) {
        final t = player.queue[i];
        final active = i == player.currentIndex;
        return ListTile(
          key: ValueKey('queue_$i\_${t.id}'),
          onTap: () => controller.jumpTo(i),
          leading: TrackArtwork(track: t, size: 40),
          title: Text(t.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: active ? AppColors.coral : AppColors.textPrimary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          subtitle: t.artist.isEmpty
              ? null
              : Text(t.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          trailing: const Icon(Icons.drag_handle_rounded, color: AppColors.textTertiary),
        );
      },
    );
  }
}
