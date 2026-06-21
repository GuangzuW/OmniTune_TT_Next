import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimens.dart';
import 'package:app/features/player/equalizer_sheet.dart';
import 'package:app/features/player/lyrics_view.dart';
import 'package:app/features/player/queue_view.dart';
import 'package:app/features/shared/track_artwork.dart';
import 'package:app/features/shared/track_tile.dart';
import 'package:app/state/player_controller.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final track = player.current;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Now Playing', style: TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.equalizer_rounded),
            tooltip: 'Equalizer',
            onPressed: () => EqualizerSheet.show(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.heroGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: track == null
              ? const Center(child: Text('Nothing playing'))
              : DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const SizedBox(height: AppDimens.xl),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
                        child: TrackArtwork(track: track, size: 280, radius: AppDimens.radiusLg),
                      ),
                      const SizedBox(height: AppDimens.xl),
                      _TrackInfo(title: track.title, artist: track.artist),
                      const SizedBox(height: AppDimens.lg),
                      _Scrubber(
                        position: player.position,
                        duration: player.duration,
                        onSeek: controller.seek,
                      ),
                      _Controls(player: player, controller: controller),
                      const SizedBox(height: AppDimens.sm),
                      _VolumeRow(volume: player.volume, onChanged: controller.setVolume),
                      const SizedBox(height: AppDimens.sm),
                      const TabBar(
                        indicatorColor: AppColors.coral,
                        labelColor: AppColors.textPrimary,
                        unselectedLabelColor: AppColors.textTertiary,
                        tabs: [Tab(text: 'Lyrics'), Tab(text: 'Up Next')],
                      ),
                      const Expanded(
                        child: TabBarView(children: [LyricsView(), QueueView()]),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  final String title;
  final String artist;
  const _TrackInfo({required this.title, required this.artist});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
      child: Column(
        children: [
          Text(title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(artist.isEmpty ? '—' : artist,
              style: const TextStyle(color: AppColors.sky, fontSize: 15)),
        ],
      ),
    );
  }
}

class _Scrubber extends StatelessWidget {
  final double position;
  final double duration;
  final ValueChanged<double> onSeek;
  const _Scrubber({required this.position, required this.duration, required this.onSeek});
  @override
  Widget build(BuildContext context) {
    final dur = duration <= 0 ? 1.0 : duration;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
      child: Column(
        children: [
          Slider(value: position.clamp(0.0, dur), max: dur, onChanged: onSeek),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatDuration(position),
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                Text(formatDuration(duration),
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final PlayerState player;
  final PlayerController controller;
  const _Controls({required this.player, required this.controller});
  @override
  Widget build(BuildContext context) {
    final repeatIcon =
        player.repeat == RepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.shuffle_rounded,
              color: player.shuffle ? AppColors.coral : AppColors.textTertiary),
          onPressed: controller.toggleShuffle,
        ),
        const SizedBox(width: AppDimens.sm),
        IconButton(
          iconSize: 36,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: controller.prev,
        ),
        const SizedBox(width: AppDimens.sm),
        GestureDetector(
          onTap: controller.togglePlay,
          child: Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle),
            child: player.buffering
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 38),
          ),
        ),
        const SizedBox(width: AppDimens.sm),
        IconButton(
          iconSize: 36,
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: () => controller.next(),
        ),
        const SizedBox(width: AppDimens.sm),
        IconButton(
          icon: Icon(repeatIcon,
              color: player.repeat == RepeatMode.off ? AppColors.textTertiary : AppColors.coral),
          onPressed: controller.cycleRepeat,
        ),
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onChanged;
  const _VolumeRow({required this.volume, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
      child: Row(
        children: [
          Icon(volume <= 0.01 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: AppColors.sky, size: 20),
          Expanded(
            child: Slider(value: volume.clamp(0.0, 1.0), onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
