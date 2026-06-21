import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/data/models/track.dart';
import 'package:app/state/providers.dart';

/// Loads the local library from the SQLite cache and supports scanning folders
/// / adding dropped files (delegating tag extraction to the native scanner).
class LibraryController extends AsyncNotifier<List<Track>> {
  @override
  Future<List<Track>> build() async {
    final cache = ref.read(metadataCacheProvider);
    final rows = await cache.getFiles();
    return rows.map(Track.fromCache).toList();
  }

  Future<int> scanFolder(String dirPath) async {
    final engine = ref.read(audioEngineProvider);
    final cache = ref.read(metadataCacheProvider);
    if (engine == null) return 0;
    final files = engine.scanDirectory(dirPath);
    for (final f in files) {
      await cache.insertFile({
        'path': f.path,
        'fileName': f.fileName,
        'title': f.title.isNotEmpty ? f.title : f.fileName,
        'artist': f.artist.isNotEmpty ? f.artist : 'Unknown Artist',
        'album': f.album.isNotEmpty ? f.album : 'Unknown Album',
        'duration': f.duration,
        'albumArtPath': f.albumArtPath,
      });
    }
    ref.invalidateSelf();
    await future;
    return files.length;
  }

  Future<void> addLocalFiles(Iterable<String> paths) async {
    final cache = ref.read(metadataCacheProvider);
    for (final path in paths) {
      final name = path.split(RegExp(r'[\\/]')).last;
      await cache.insertFile({
        'path': path,
        'fileName': name,
        'title': name,
        'artist': 'Unknown Artist',
        'album': 'Unknown Album',
        'duration': 0.0,
        'albumArtPath': '',
      });
    }
    ref.invalidateSelf();
    await future;
  }
}

final libraryControllerProvider =
    AsyncNotifierProvider<LibraryController, List<Track>>(LibraryController.new);
