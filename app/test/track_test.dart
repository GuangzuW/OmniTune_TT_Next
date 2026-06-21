import 'package:flutter_test/flutter_test.dart';

import 'package:app/data/models/track.dart';

void main() {
  test('fromCache maps a local row', () {
    final t = Track.fromCache({
      'path': '/music/a.mp3',
      'title': 'Song A',
      'artist': 'Artist X',
      'album': 'Album',
      'duration': 123.0,
      'albumArtPath': '',
    });
    expect(t.id, '/music/a.mp3');
    expect(t.title, 'Song A');
    expect(t.artist, 'Artist X');
    expect(t.duration, 123.0);
    expect(t.isRemote, isFalse);
  });

  test('fromCache falls back to fileName when title is empty', () {
    final t = Track.fromCache({'path': '/m/a.mp3', 'fileName': 'a.mp3', 'title': ''});
    expect(t.title, 'a.mp3');
  });

  test('remote track serializes with an audius: ref', () {
    const t = Track(id: 'abc123', title: 'T', artist: 'A', source: TrackSource.audius);
    expect(t.isRemote, isTrue);
    final m = t.toPlaylistTrack(2);
    expect(m['ref'], 'audius:abc123');
    expect(m['position'], 2);
  });

  test('local track serializes with its raw path', () {
    const t = Track(id: '/m/a.mp3', title: 'T', artist: 'A', source: TrackSource.local);
    expect(t.toPlaylistTrack(0)['ref'], '/m/a.mp3');
  });
}
