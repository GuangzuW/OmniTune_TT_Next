import 'package:flutter/material.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/data/models/track.dart';
import 'package:app/features/shared/track_artwork.dart';

String formatDuration(double seconds) {
  if (seconds.isNaN || seconds < 0) seconds = 0;
  final m = (seconds / 60).floor();
  final s = (seconds % 60).floor();
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// A single track row used across search, library and playlists.
class TrackTile extends StatelessWidget {
  final Track track;
  final bool active;
  final bool playing;
  final VoidCallback onTap;
  final Widget? trailing;
  final int? index;

  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.active = false,
    this.playing = false,
    this.trailing,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: SizedBox(
        width: 44,
        child: active && playing
            ? const Icon(Icons.graphic_eq_rounded, color: AppColors.coral)
            : TrackArtwork(track: track, size: 44),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: active ? AppColors.coral : AppColors.textPrimary,
          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      subtitle: track.artist.isEmpty
          ? null
          : Text(track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
      trailing: trailing ??
          (track.duration > 0
              ? Text(formatDuration(track.duration),
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12))
              : null),
    );
  }
}
