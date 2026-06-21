import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimens.dart';
import 'package:app/features/shared/track_tile.dart';
import 'package:app/state/player_controller.dart';
import 'package:app/state/search_controller.dart' as sc;

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(sc.searchControllerProvider.notifier).search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(sc.searchControllerProvider);
    final player = ref.read(playerControllerProvider.notifier);
    final current = ref.watch(playerControllerProvider.select((s) => s.current));
    final playing = ref.watch(playerControllerProvider.select((s) => s.isPlaying));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Search', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              onSubmitted: (v) => ref.read(sc.searchControllerProvider.notifier).search(v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary),
                hintText: 'Songs, artists on Audius...',
              ),
            ),
            const SizedBox(height: AppDimens.md),
            Expanded(
              child: results.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: AppColors.coral)),
                error: (e, _) => Center(
                    child: Text('Search failed.\n$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textTertiary))),
                data: (tracks) {
                  if (tracks.isEmpty) {
                    return const Center(
                        child: Text('Search millions of tracks on Audius',
                            style: TextStyle(color: AppColors.textTertiary)));
                  }
                  return ListView.builder(
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
            ),
          ],
        ),
      ),
    );
  }
}
