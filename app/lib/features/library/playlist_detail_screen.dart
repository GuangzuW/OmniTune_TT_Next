import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimens.dart';
import 'package:app/data/models/track.dart';
import 'package:app/features/shared/track_tile.dart';
import 'package:app/state/player_controller.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final Map<String, dynamic>? playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  List<Track> _tracks() {
    final raw = (playlist?['tracks'] as List<dynamic>?) ?? const [];
    return raw.map((e) {
      final m = e as Map<String, dynamic>;
      final ref = (m['ref'] ?? '').toString();
      final title = (m['title'] ?? '').toString();
      final artist = (m['artist'] ?? '').toString();
      if (ref.startsWith('audius:')) {
        return Track(
            id: ref.substring(7),
            title: title,
            artist: artist,
            source: TrackSource.audius);
      }
      return Track(
          id: ref,
          title: title.isNotEmpty ? title : ref.split(RegExp(r'[\\/]')).last,
          artist: artist,
          source: TrackSource.local);
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = (playlist?['name'] ?? 'Playlist').toString();
    final tracks = _tracks();
    final player = ref.read(playerControllerProvider.notifier);
    final current = ref.watch(playerControllerProvider.select((s) => s.current));
    final playing = ref.watch(playerControllerProvider.select((s) => s.isPlaying));

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimens.xl),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.heroGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: const Icon(Icons.queue_music_rounded, color: AppColors.coral, size: 44),
                ),
                const SizedBox(width: AppDimens.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${tracks.length} tracks',
                          style: const TextStyle(color: AppColors.sky)),
                      const SizedBox(height: AppDimens.md),
                      FilledButton.icon(
                        onPressed: tracks.isEmpty
                            ? null
                            : () => player.playQueue(tracks, startIndex: 0),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, i) {
                final t = tracks[i];
                return TrackTile(
                  track: t,
                  active: current?.id == t.id,
                  playing: playing,
                  onTap: () => player.playQueue(tracks, startIndex: i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
