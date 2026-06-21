import 'package:app/data/services/audio_player_ffi.dart';
import 'package:app/data/services/remote_api.dart';

enum TrackSource { local, audius }

/// A unified track that can originate from the local library or Audius.
class Track {
  final String id; // local file path OR audius track id
  final String title;
  final String artist;
  final String album;
  final double duration; // seconds
  final String artworkUrl; // network artwork (remote)
  final String albumArtPath; // local art file path
  final TrackSource source;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.duration = 0,
    this.artworkUrl = '',
    this.albumArtPath = '',
    required this.source,
  });

  bool get isRemote => source == TrackSource.audius;

  factory Track.fromLocal(AudioFileInfo f) => Track(
        id: f.path,
        title: f.title.isNotEmpty ? f.title : f.fileName,
        artist: f.artist,
        album: f.album,
        duration: f.duration,
        albumArtPath: f.albumArtPath,
        source: TrackSource.local,
      );

  factory Track.fromAudius(AudiusTrack t) => Track(
        id: t.id,
        title: t.title,
        artist: t.artist,
        duration: t.duration.toDouble(),
        artworkUrl: t.artworkUrl,
        source: TrackSource.audius,
      );

  factory Track.fromCache(Map<String, dynamic> m) => Track(
        id: (m['path'] ?? '') as String,
        title: ((m['title'] as String?)?.isNotEmpty ?? false)
            ? m['title'] as String
            : (m['fileName'] ?? '') as String,
        artist: (m['artist'] ?? '') as String,
        album: (m['album'] ?? '') as String,
        duration: ((m['duration'] as num?) ?? 0).toDouble(),
        albumArtPath: (m['albumArtPath'] ?? '') as String,
        source: TrackSource.local,
      );

  /// Shape expected by the user-sync `/sync/playlist` endpoint.
  Map<String, dynamic> toPlaylistTrack(int position) => {
        'ref': isRemote ? 'audius:$id' : id,
        'title': title,
        'artist': artist,
        'position': position,
      };
}
