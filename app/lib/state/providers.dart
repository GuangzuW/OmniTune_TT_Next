import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/data/services/audio_player_ffi.dart';
import 'package:app/data/services/background_audio.dart';
import 'package:app/data/services/metadata_cache.dart';
import 'package:app/data/services/remote_api.dart';

/// Native audio engine. Overridden in main() with the real instance (or left
/// null if the core failed to load, so the app still runs).
final audioEngineProvider = Provider<AudioPlayerFFI?>((ref) => null);

/// OS media-control handler (audio_service). Overridden in main().
final audioHandlerProvider = Provider<BackgroundAudioHandler?>((ref) => null);

/// Backend client (Audius search/stream + cloud auth/playlists).
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Local SQLite metadata cache.
final metadataCacheProvider = Provider<MetadataCache>((ref) => MetadataCache());
