import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A track returned by the Audius aggregator search.
class AudiusTrack {
  final String id;
  final String title;
  final String artist;
  final int duration; // seconds
  final String artworkUrl;
  AudiusTrack(this.id, this.title, this.artist, {this.duration = 0, this.artworkUrl = ""});

  factory AudiusTrack.fromJson(Map<String, dynamic> j) {
    final user = j['user'];
    final artist = (user is Map && user['name'] is String) ? user['name'] as String : '';
    final art = j['artwork'];
    final artworkUrl = (art is Map)
        ? (art['480x480'] ?? art['150x150'] ?? '').toString()
        : '';
    return AudiusTrack(
      (j['id'] ?? '').toString(),
      (j['title'] ?? '').toString(),
      artist,
      duration: (j['duration'] is num) ? (j['duration'] as num).toInt() : 0,
      artworkUrl: artworkUrl,
    );
  }
}

/// Talks to the Go backend: the aggregator (Audius search/stream, :8000) and
/// the user-sync service (JWT auth + cloud playlists, :8001).
///
/// Base URLs are overridable at build time:
///   flutter run --dart-define=AGGREGATOR_URL=http://host:8000 \
///               --dart-define=USERSYNC_URL=http://host:8001
class ApiClient {
  static const String aggregatorUrl =
      String.fromEnvironment('AGGREGATOR_URL', defaultValue: 'http://localhost:8000');
  static const String userSyncUrl =
      String.fromEnvironment('USERSYNC_URL', defaultValue: 'http://localhost:8001');

  String? _accessToken;
  String? _refreshToken;
  bool get isLoggedIn => _accessToken != null;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  void setTokens({String? access, String? refresh}) {
    _accessToken = access;
    if (refresh != null) _refreshToken = refresh;
  }

  // ---- Aggregator (Audius) ----

  Future<List<AudiusTrack>> searchTracks(String query) async {
    final uri = Uri.parse('$aggregatorUrl/search?query=${Uri.encodeQueryComponent(query)}');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Search failed: ${resp.statusCode}');
    }
    final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
    return data.map((e) => AudiusTrack.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Downloads a track's audio to a temp file (the native core plays from a
  /// path; miniaudio has no network I/O) and returns the local path.
  Future<String> downloadTrack(AudiusTrack track) async {
    final uri = Uri.parse('$aggregatorUrl/stream/${track.id}');
    final resp = await http.get(uri); // http client follows the 302 to Audius
    if (resp.statusCode != 200) {
      throw Exception('Stream failed: ${resp.statusCode}');
    }
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'audius_${track.id}.mp3'));
    await file.writeAsBytes(resp.bodyBytes);
    return file.path;
  }

  /// Downloads a track by its Audius id (used by the unified Track model).
  Future<String> downloadById(String id) async {
    final resp = await http.get(Uri.parse('$aggregatorUrl/stream/$id'));
    if (resp.statusCode != 200) {
      throw Exception('Stream failed: ${resp.statusCode}');
    }
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'audius_$id.mp3'));
    await file.writeAsBytes(resp.bodyBytes);
    return file.path;
  }

  // ---- User sync (auth + playlists) ----

  Future<void> register(String username, String password) =>
      _auth('/auth/register', username, password);

  Future<void> login(String username, String password) =>
      _auth('/auth/login', username, password);

  Future<void> _auth(String path, String username, String password) async {
    final resp = await http.post(
      Uri.parse('$userSyncUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Auth failed (${resp.statusCode}): ${resp.body.trim()}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    _accessToken = (body['access'] ?? body['token']) as String?;
    _refreshToken = body['refresh'] as String?;
  }

  /// Exchanges the refresh token for a fresh access token. Returns false if the
  /// refresh token is missing/expired (caller should force re-login).
  Future<bool> refresh() async {
    if (_refreshToken == null) return false;
    final resp = await http.post(
      Uri.parse('$userSyncUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': _refreshToken}),
    );
    if (resp.statusCode != 200) {
      _accessToken = null;
      return false;
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    _accessToken = (body['access'] ?? body['token']) as String?;
    return _accessToken != null;
  }

  Future<void> logout() async {
    if (_refreshToken != null) {
      try {
        await http.post(
          Uri.parse('$userSyncUrl/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh': _refreshToken}),
        );
      } catch (_) {}
    }
    _accessToken = null;
    _refreshToken = null;
  }

  /// Performs an authenticated request, transparently refreshing the access
  /// token once on a 401 and retrying.
  Future<http.Response> _authed(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    if (_accessToken == null) throw Exception('Not logged in');
    var resp = await send({'Authorization': 'Bearer $_accessToken'});
    if (resp.statusCode == 401 && await refresh()) {
      resp = await send({'Authorization': 'Bearer $_accessToken'});
    }
    return resp;
  }

  /// Pushes a playlist (name + ordered tracks) to the server.
  Future<void> syncPlaylist(String name, List<Map<String, dynamic>> tracks) async {
    final body = jsonEncode({
      'name': name,
      'tracks': [
        for (var i = 0; i < tracks.length; i++)
          {
            'ref': tracks[i]['path'] ?? tracks[i]['ref'] ?? '',
            'title': tracks[i]['title'] ?? tracks[i]['fileName'] ?? '',
            'artist': tracks[i]['artist'] ?? '',
            'position': i,
          }
      ],
    });
    final resp = await _authed((headers) => http.post(
          Uri.parse('$userSyncUrl/sync/playlist'),
          headers: {'Content-Type': 'application/json', ...headers},
          body: body,
        ));
    if (resp.statusCode != 200) {
      throw Exception('Sync failed (${resp.statusCode}): ${resp.body.trim()}');
    }
  }

  /// Fetches all cloud playlists for the logged-in user.
  Future<List<dynamic>> fetchPlaylists() async {
    final resp = await _authed((headers) => http.get(
          Uri.parse('$userSyncUrl/playlists'),
          headers: headers,
        ));
    if (resp.statusCode != 200) {
      throw Exception('Fetch failed (${resp.statusCode}): ${resp.body.trim()}');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }
}
