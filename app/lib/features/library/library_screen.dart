import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimens.dart';
import 'package:app/features/shared/track_tile.dart';
import 'package:app/state/library_controller.dart';
import 'package:app/state/player_controller.dart';
import 'package:app/state/providers.dart';

final cloudPlaylistsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.read(apiClientProvider).fetchPlaylists();
});

const _audioExt = {'.mp3', '.flac', '.ape', '.wav', '.ogg', '.m4a'};

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final libController = ref.read(libraryControllerProvider.notifier);
    final player = ref.read(playerControllerProvider.notifier);
    final current = ref.watch(playerControllerProvider.select((s) => s.current));
    final playing = ref.watch(playerControllerProvider.select((s) => s.isPlaying));

    Future<void> pickFolder() async {
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir != null) {
        final n = await libController.scanFolder(dir);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Added $n tracks')));
        }
      }
    }

    return SafeArea(
      child: DropTarget(
        onDragDone: (detail) async {
          final paths = detail.files
              .map((f) => f.path)
              .where((p) => _audioExt.any((e) => p.toLowerCase().endsWith(e)));
          if (paths.isNotEmpty) await libController.addLocalFiles(paths);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppDimens.lg, AppDimens.lg, AppDimens.lg, AppDimens.sm),
                child: Row(
                  children: [
                    const Text('Your Library',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: pickFolder,
                      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                      label: const Text('Add folder'),
                    ),
                  ],
                ),
              ),
            ),
            _CloudPlaylists(),
            library.when(
              loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.coral))),
              error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('$e', style: const TextStyle(color: AppColors.textTertiary)))),
              data: (tracks) {
                if (tracks.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.all(AppDimens.xxl),
                      child: Center(
                        child: Text('Drop audio files here, or use "Add folder"',
                            style: TextStyle(color: AppColors.textTertiary)),
                      ),
                    ),
                  );
                }
                return SliverList.builder(
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CloudPlaylists extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(cloudPlaylistsProvider);
    return cloud.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.sm),
          child: Text('Log in (Settings) to see cloud playlists',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ),
      ),
      data: (playlists) {
        if (playlists.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(AppDimens.lg, AppDimens.sm, AppDimens.lg, AppDimens.sm),
                  child: Text('Cloud Playlists',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                    itemCount: playlists.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppDimens.sm),
                    itemBuilder: (context, i) {
                      final pl = playlists[i] as Map<String, dynamic>;
                      return ActionChip(
                        backgroundColor: AppColors.card,
                        label: Text('${pl['name'] ?? 'Playlist'}'),
                        avatar: const Icon(Icons.queue_music_rounded, color: AppColors.coral, size: 18),
                        onPressed: () => context.push('/library/playlist', extra: pl),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
