import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/data/services/audio_player_ffi.dart';
import 'package:app/state/player_controller.dart';
import 'package:app/state/providers.dart';

/// Parses the sibling .lrc file for the current local track.
final currentLyricsProvider = FutureProvider.autoDispose<List<LyricLine>>((ref) async {
  final track = ref.watch(playerControllerProvider.select((s) => s.current));
  final engine = ref.read(audioEngineProvider);
  if (track == null || engine == null || track.isRemote) return [];
  final lrcPath = track.id
      .replaceAll(RegExp(r'\.(mp3|flac|ape|wav|ogg)$', caseSensitive: false), '.lrc');
  final f = File(lrcPath);
  if (!f.existsSync()) return [];
  return engine.parseLyrics(await f.readAsString());
});

class LyricsView extends ConsumerWidget {
  const LyricsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsAsync = ref.watch(currentLyricsProvider);
    final position = ref.watch(playerControllerProvider.select((s) => s.position));

    return lyricsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral)),
      error: (_, __) => const _NoLyrics(),
      data: (lines) {
        if (lines.isEmpty) return const _NoLyrics();
        int activeIndex = 0;
        for (var i = 0; i < lines.length; i++) {
          if (position >= lines[i].timestamp) {
            activeIndex = i;
          } else {
            break;
          }
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          itemCount: lines.length,
          itemBuilder: (context, i) {
            final active = i == activeIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                lines[i].text.isEmpty ? '♪' : lines[i].text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: active ? 20 : 16,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? AppColors.coral : AppColors.textTertiary,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NoLyrics extends StatelessWidget {
  const _NoLyrics();
  @override
  Widget build(BuildContext context) => const Center(
        child: Text('No lyrics found\n(place a matching .lrc next to the file)',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textTertiary)),
      );
}
