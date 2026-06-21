import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimens.dart';
import 'package:app/data/models/track.dart';
import 'package:app/features/shared/track_artwork.dart';
import 'package:app/state/library_controller.dart';
import 'package:app/state/player_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final player = ref.read(playerControllerProvider.notifier);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppDimens.lg, AppDimens.xl, AppDimens.lg, AppDimens.sm),
              child: Text('Good vibes',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            ),
          ),
          library.when(
            loading: () => const SliverToBoxAdapter(
                child: Padding(
                    padding: EdgeInsets.all(AppDimens.xxl),
                    child: Center(child: CircularProgressIndicator(color: AppColors.coral)))),
            error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.all(AppDimens.xxl),
                    child: Center(child: Text('$e', style: const TextStyle(color: AppColors.textTertiary))))),
            data: (tracks) {
              if (tracks.isEmpty) return const SliverToBoxAdapter(child: _EmptyHome());
              return SliverPadding(
                padding: const EdgeInsets.all(AppDimens.lg),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: AppDimens.lg,
                    crossAxisSpacing: AppDimens.lg,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _AlbumCard(
                      track: tracks[i],
                      onTap: () => player.playQueue(tracks, startIndex: i),
                    ),
                    childCount: tracks.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  const _AlbumCard({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => TrackArtwork(
                  track: track, size: c.maxWidth, radius: AppDimens.radiusMd),
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          Text(track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.xxl),
      child: Column(
        children: [
          const SizedBox(height: AppDimens.xxl),
          const Icon(Icons.library_music_rounded, size: 64, color: AppColors.navy),
          const SizedBox(height: AppDimens.lg),
          const Text('Your library is empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppDimens.sm),
          const Text('Add local music or stream from Audius.',
              style: TextStyle(color: AppColors.textTertiary)),
          const SizedBox(height: AppDimens.lg),
          Wrap(
            spacing: AppDimens.md,
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/library'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add music'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/search'),
                icon: const Icon(Icons.search_rounded),
                label: const Text('Search Audius'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
