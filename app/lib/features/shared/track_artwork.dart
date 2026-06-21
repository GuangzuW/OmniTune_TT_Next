import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimens.dart';
import 'package:app/data/models/track.dart';

/// Shows a track's artwork: network image (Audius), local art file, or a
/// branded placeholder.
class TrackArtwork extends StatelessWidget {
  final Track? track;
  final double size;
  final double radius;
  const TrackArtwork({super.key, required this.track, this.size = 48, this.radius = AppDimens.radiusSm});

  @override
  Widget build(BuildContext context) {
    final t = track;
    Widget placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.music_note_rounded, color: AppColors.sky, size: size * 0.4),
    );

    Widget? image;
    if (t != null && t.artworkUrl.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: t.artworkUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      );
    } else if (t != null && t.albumArtPath.isNotEmpty && File(t.albumArtPath).existsSync()) {
      image = Image.file(File(t.albumArtPath), width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image ?? placeholder,
    );
  }
}
