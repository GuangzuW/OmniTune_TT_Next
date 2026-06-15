import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:audio_service/audio_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'audio_player_ffi.dart';
import 'api_client.dart';
import 'metadata_cache.dart';
import 'tray_service.dart';
import 'background_audio.dart';

late BackgroundAudioHandler _audioHandler;

// Retro skin palette
const Color kBg = Color(0xFF121212);
const Color kPanel = Color(0xFF1C1C1C);
const Color kPanelBorder = Color(0xFF2E2E2E);
const Color kAccent = Color(0xFF39FF14); // classic LCD green
const Color kAccentDim = Color(0xFF1F7A12);
const Color kLcdBg = Color(0xFF071207);

const List<int> kEqFreqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
const Map<String, List<double>> kEqPresets = {
  'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'Rock': [4, 3, -1, -2, -1, 1, 3, 4, 4, 4],
  'Pop': [-1, 1, 3, 4, 3, 0, -1, -1, -1, -1],
  'Jazz': [3, 2, 1, 2, -1, -1, 0, 1, 2, 3],
  'Bass': [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
  'Vocal': [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1],
};

enum RepeatMode { off, all, one }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(980, 640),
      minimumSize: Size(720, 480),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    await hotKeyManager.unregisterAll();
  }
  runApp(const TTPlayerApp());
}

class TTPlayerApp extends StatelessWidget {
  const TTPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniTune TT Next',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(seedColor: kAccent, brightness: Brightness.dark),
        sliderTheme: const SliderThemeData(
          trackHeight: 3,
          overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
        ),
        useMaterial3: true,
      ),
      home: const PlayerHomePage(title: 'OmniTune TT Next'),
    );
  }
}

class PlayerHomePage extends StatefulWidget {
  const PlayerHomePage({super.key, required this.title});
  final String title;

  @override
  State<PlayerHomePage> createState() => _PlayerHomePageState();
}

class _PlayerHomePageState extends State<PlayerHomePage> with WindowListener {
  AudioPlayerFFI? _player;
  bool _libReady = false;

  bool _isPlaying = false;
  double _position = 0.0;
  double _duration = 1.0;
  double _volume = 1.0;
  Timer? _timer;

  final MetadataCache _cache = MetadataCache();
  List<Map<String, dynamic>> _playlist = [];
  List<LyricLine> _lyrics = [];
  String _currentLyric = "";

  final List<double> _eqGains = List.filled(10, 0.0);
  String _eqPreset = 'Flat';

  String _currentTitle = "No song loaded";
  String _currentArtist = "";
  String _currentAlbumArt = "";
  String _currentArtworkUrl = "";
  int _currentIndex = -1;

  bool _shuffle = false;
  RepeatMode _repeat = RepeatMode.off;

  bool _showPlaylist = true;
  bool _showEqualizer = false;
  bool _showFloatingLyrics = false;
  bool _showOnline = false;

  bool _scanning = false;
  String _statusMsg = "";

  // Cloud / online
  final ApiClient _api = ApiClient();
  final TextEditingController _searchCtrl = TextEditingController();
  List<AudiusTrack> _searchResults = [];
  bool _searching = false;

  Offset _lyricsOffset = const Offset(60, 80);
  final Random _rng = Random();
  late TrayService _trayService;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initServices();
    _initHotKeys();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _timer?.cancel();
    _searchCtrl.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _initHotKeys() async {
    try {
      await hotKeyManager.register(
        HotKey(KeyCode.keyP, modifiers: [KeyModifier.alt], scope: HotKeyScope.system),
        keyDownHandler: (_) => _togglePlay(),
      );
      await hotKeyManager.register(
        HotKey(KeyCode.keyS, modifiers: [KeyModifier.alt], scope: HotKeyScope.system),
        keyDownHandler: (_) => _stop(),
      );
      await hotKeyManager.register(
        HotKey(KeyCode.arrowRight, modifiers: [KeyModifier.alt], scope: HotKeyScope.system),
        keyDownHandler: (_) => _next(),
      );
      await hotKeyManager.register(
        HotKey(KeyCode.arrowLeft, modifiers: [KeyModifier.alt], scope: HotKeyScope.system),
        keyDownHandler: (_) => _prev(),
      );
    } catch (e) {
      debugPrint('Hotkey registration failed: $e');
    }
  }

  Future<void> _initServices() async {
    _trayService = TrayService(
      onPlayPause: _togglePlay,
      onNext: _next,
      onPrev: _prev,
      onQuit: () => exit(0),
    );
    try {
      await _trayService.init();
    } catch (e) {
      debugPrint('Tray init failed: $e');
    }

    if (!kIsWeb) {
      try {
        _player = AudioPlayerFFI();
        _libReady = true;
        _volume = _player!.getVolume();
        _audioHandler = await AudioService.init(
          builder: () => BackgroundAudioHandler(_player!),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.omnitune.app.channel.audio',
            androidNotificationChannelName: 'Music Playback',
            androidNotificationOngoing: true,
          ),
        );
        _audioHandler.onNext = _next;
        _audioHandler.onPrev = _prev;
        _startUpdateTimer();
      } catch (e) {
        debugPrint('Failed to initialize audio engine: $e');
        setState(() => _statusMsg = 'Audio core not found — build it with scripts/build_desktop');
      }
    }
    await _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    try {
      final files = await _cache.getFiles();
      setState(() => _playlist = List<Map<String, dynamic>>.from(files));
    } catch (e) {
      debugPrint('Load playlist failed: $e');
    }
  }

  void _updateCurrentLyric() {
    if (_lyrics.isEmpty) {
      if (_currentLyric != "") setState(() => _currentLyric = "");
      return;
    }
    String found = "";
    for (var i = 0; i < _lyrics.length; i++) {
      if (_position >= _lyrics[i].timestamp) {
        found = _lyrics[i].text;
      } else {
        break;
      }
    }
    if (_currentLyric != found) setState(() => _currentLyric = found);
  }

  // ---- Library / scanning ----

  Future<void> _pickAndScanFolder() async {
    if (_player == null) {
      setState(() => _statusMsg = 'Audio core unavailable');
      return;
    }
    String? dir;
    try {
      dir = await FilePicker.platform.getDirectoryPath();
    } catch (e) {
      debugPrint('Folder picker failed: $e');
    }
    dir ??= Directory.current.path;
    await _scanDirectory(dir);
  }

  Future<void> _scanDirectory(String scanPath) async {
    if (_player == null) return;
    setState(() {
      _scanning = true;
      _statusMsg = 'Scanning $scanPath ...';
    });
    // Yield so the spinner paints before the (blocking) native scan.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      final files = _player!.scanDirectory(scanPath);
      for (final file in files) {
        await _cache.insertFile({
          'path': file.path,
          'fileName': file.fileName,
          'title': file.title.isNotEmpty ? file.title : file.fileName,
          'artist': file.artist.isNotEmpty ? file.artist : 'Unknown Artist',
          'album': file.album.isNotEmpty ? file.album : 'Unknown Album',
          'duration': file.duration,
          'albumArtPath': file.albumArtPath,
        });
      }
      await _loadPlaylist();
      setState(() => _statusMsg = 'Added ${files.length} tracks');
    } catch (e) {
      setState(() => _statusMsg = 'Scan error: $e');
    } finally {
      setState(() => _scanning = false);
    }
  }

  // ---- Transport ----

  void _startUpdateTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_player == null) return;
      if (_player!.isPlaying()) {
        setState(() {
          _position = _player!.getPosition();
          _duration = _player!.getDuration();
          if (_duration <= 0) _duration = 1.0;
          if (_position > _duration) _position = _duration;
        });
        _updateCurrentLyric();
      } else if (_isPlaying) {
        // Engine stopped while we believed it was playing → track ended.
        if (_duration > 0 && _position >= _duration - 0.6) {
          _onTrackEnded();
        }
      }
    });
  }

  void _onTrackEnded() {
    if (_repeat == RepeatMode.one && _currentIndex >= 0) {
      _playTrackAt(_currentIndex);
    } else {
      _next(auto: true);
    }
  }

  void _togglePlay() {
    if (_player == null) return;
    if (_currentIndex < 0 && _currentTitle == "No song loaded" && _playlist.isNotEmpty) {
      _playTrackAt(0);
      return;
    }
    setState(() {
      if (_player!.isPlaying()) {
        _audioHandler.pause();
        _isPlaying = false;
      } else {
        _audioHandler.play();
        _isPlaying = true;
      }
    });
  }

  void _stop() {
    if (_player == null) return;
    _audioHandler.stop();
    setState(() {
      _isPlaying = false;
      _position = 0.0;
      _currentLyric = "";
    });
  }

  void _setVolume(double v) {
    setState(() => _volume = v);
    _player?.setVolume(v);
  }

  void _seek(double seconds) {
    setState(() => _position = seconds);
    _audioHandler.seek(Duration(milliseconds: (seconds * 1000).toInt()));
  }

  Future<void> _loadLyrics(String musicPath) async {
    final lrcPath = musicPath.replaceAll(RegExp(r'\.(mp3|flac|ape|wav|ogg)$', caseSensitive: false), '.lrc');
    try {
      final lrcFile = File(lrcPath);
      if (await lrcFile.exists()) {
        final content = await lrcFile.readAsString();
        setState(() => _lyrics = _player!.parseLyrics(content));
        return;
      }
    } catch (_) {}
    setState(() {
      _lyrics = [];
      _currentLyric = "";
    });
  }

  void _playTrackAt(int index) {
    if (_player == null || _playlist.isEmpty) return;
    if (index < 0 || index >= _playlist.length) return;
    final item = _playlist[index];
    final String path = item['path'];
    if (!_player!.load(path)) {
      setState(() => _statusMsg = 'Failed to load: ${item['fileName']}');
      return;
    }
    final String fileName = item['fileName'] ?? '';
    final String rawTitle = (item['title'] as String?) ?? '';
    final String title = rawTitle.isNotEmpty ? rawTitle : fileName;
    final String artist = (item['artist'] as String?) ?? '';

    setState(() {
      _currentIndex = index;
      _currentTitle = title;
      _currentArtist = artist;
      _currentAlbumArt = (item['albumArtPath'] as String?) ?? '';
      _currentArtworkUrl = "";
      _position = 0.0;
      _isPlaying = true;
      _statusMsg = "";
    });
    _loadLyrics(path);
    _audioHandler.updateMetadata(title, artist, Duration(seconds: _player!.getDuration().toInt()));
    _audioHandler.play();
  }

  void _next({bool auto = false}) {
    if (_playlist.isEmpty || _player == null) return;
    if (_shuffle) {
      if (_playlist.length == 1) {
        _playTrackAt(0);
      } else {
        int idx;
        do {
          idx = _rng.nextInt(_playlist.length);
        } while (idx == _currentIndex);
        _playTrackAt(idx);
      }
      return;
    }
    final next = _currentIndex + 1;
    if (next >= _playlist.length) {
      if (auto && _repeat == RepeatMode.off) {
        setState(() => _isPlaying = false); // reached the end
        return;
      }
      _playTrackAt(0); // wrap (manual next, or repeat-all)
    } else {
      _playTrackAt(next);
    }
  }

  void _prev() {
    if (_playlist.isEmpty || _player == null) return;
    final start = _currentIndex < 0 ? 0 : _currentIndex;
    _playTrackAt((start - 1 + _playlist.length) % _playlist.length);
  }

  void _applyEqPreset(String name) {
    final preset = kEqPresets[name];
    if (preset == null) return;
    setState(() {
      _eqPreset = name;
      for (var i = 0; i < _eqGains.length; i++) {
        _eqGains[i] = preset[i];
        _player?.setEqBandGain(i, preset[i]);
      }
    });
  }

  // ---- Online / cloud ----

  Future<void> _searchOnline() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    try {
      final results = await _api.searchTracks(query);
      setState(() => _searchResults = results);
    } catch (e) {
      setState(() => _statusMsg = 'Search error: $e');
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _playOnline(AudiusTrack track) async {
    if (_player == null) return;
    setState(() => _statusMsg = 'Buffering "${track.title}"...');
    try {
      final path = await _api.downloadTrack(track);
      if (!_player!.load(path)) {
        setState(() => _statusMsg = 'Failed to load stream');
        return;
      }
      setState(() {
        _currentIndex = -1;
        _currentTitle = track.title;
        _currentArtist = track.artist;
        _currentAlbumArt = "";
        _currentArtworkUrl = track.artworkUrl;
        _position = 0.0;
        _isPlaying = true;
        _statusMsg = "";
        _lyrics = [];
        _currentLyric = "";
      });
      _audioHandler.updateMetadata(track.title, track.artist, Duration(seconds: _player!.getDuration().toInt()));
      _audioHandler.play();
    } catch (e) {
      setState(() => _statusMsg = 'Stream error: $e');
    }
  }

  Future<void> _showLoginDialog() async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('Cloud Account', style: TextStyle(color: kAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: userCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Username')),
            TextField(controller: passCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Password')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => _doAuth(() => _api.register(userCtrl.text.trim(), passCtrl.text), ctx), child: const Text('Register')),
          TextButton(onPressed: () => _doAuth(() => _api.login(userCtrl.text.trim(), passCtrl.text), ctx), child: const Text('Login')),
        ],
      ),
    );
  }

  Future<void> _doAuth(Future<void> Function() action, BuildContext dialogCtx) async {
    try {
      await action();
      if (mounted) Navigator.of(dialogCtx).pop();
      setState(() => _statusMsg = 'Logged in');
    } catch (e) {
      setState(() => _statusMsg = '$e');
    }
  }

  Future<void> _syncToCloud() async {
    if (!_api.isLoggedIn) {
      await _showLoginDialog();
      if (!_api.isLoggedIn) return;
    }
    try {
      await _api.syncPlaylist('Default', _playlist);
      setState(() => _statusMsg = 'Synced ${_playlist.length} tracks to cloud');
    } catch (e) {
      setState(() => _statusMsg = 'Sync error: $e');
    }
  }

  Future<void> _loadFromCloud() async {
    if (!_api.isLoggedIn) {
      await _showLoginDialog();
      if (!_api.isLoggedIn) return;
    }
    try {
      final playlists = await _api.fetchPlaylists();
      int imported = 0;
      for (final pl in playlists) {
        final tracks = (pl['tracks'] as List<dynamic>?) ?? [];
        for (final t in tracks) {
          final ref = (t['ref'] ?? '').toString();
          if (ref.isEmpty) continue;
          await _cache.insertFile({
            'path': ref,
            'fileName': ref.split(Platform.pathSeparator).last,
            'title': (t['title'] ?? '').toString(),
            'artist': (t['artist'] ?? '').toString(),
            'album': '',
            'duration': 0.0,
            'albumArtPath': '',
          });
          imported++;
        }
      }
      await _loadPlaylist();
      setState(() => _statusMsg = 'Imported $imported tracks from cloud');
    } catch (e) {
      setState(() => _statusMsg = 'Load error: $e');
    }
  }

  // ---- helpers ----

  String _formatTime(double seconds) {
    if (seconds.isNaN || seconds < 0) seconds = 0;
    final int m = (seconds / 60).floor();
    final int s = (seconds % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _artwork(double size) {
    Widget placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kLcdBg,
        border: Border.all(color: kAccentDim),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.music_note, color: kAccent.withOpacity(0.5), size: size * 0.4),
    );
    ImageProvider? provider;
    if (_currentArtworkUrl.isNotEmpty) {
      provider = NetworkImage(_currentArtworkUrl);
    } else if (_currentAlbumArt.isNotEmpty && File(_currentAlbumArt).existsSync()) {
      provider = FileImage(File(_currentAlbumArt));
    }
    if (provider == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image(
        image: provider,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (detail) async {
        for (final file in detail.files) {
          try {
            if (File(file.path).statSync().type == FileSystemEntityType.file) {
              await _cache.insertFile({
                'path': file.path,
                'fileName': file.name,
                'title': file.name,
                'artist': 'Unknown Artist',
                'album': 'Unknown Album',
                'duration': 0.0,
                'albumArtPath': '',
              });
            }
          } catch (_) {}
        }
        await _loadPlaylist();
        setState(() => _statusMsg = 'Added dropped files');
      },
      child: Scaffold(
        body: Column(
          children: [
            _buildTitleBar(),
            _buildNowPlaying(),
            _buildToggleBar(),
            Expanded(child: _buildPanels()),
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 36,
        color: Colors.black,
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.graphic_eq, color: kAccent, size: 18),
            const SizedBox(width: 8),
            const Text('OmniTune TT Next', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const Spacer(),
            if (_api.isLoggedIn) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.cloud_done, color: kAccent, size: 16)),
            IconButton(splashRadius: 16, icon: const Icon(Icons.remove, size: 18, color: Colors.white70), onPressed: () => windowManager.minimize()),
            IconButton(splashRadius: 16, icon: const Icon(Icons.close, size: 18, color: Colors.white70), onPressed: () => windowManager.close()),
          ],
        ),
      ),
    );
  }

  Widget _buildNowPlaying() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kLcdBg,
        border: Border.all(color: kAccentDim, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: kAccent.withOpacity(0.08), blurRadius: 18, spreadRadius: 1)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _artwork(96),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_currentTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kAccent, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Courier', letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(_currentArtist.isEmpty ? '—' : _currentArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: kAccent.withOpacity(0.7), fontSize: 12, fontFamily: 'Courier')),
                const SizedBox(height: 2),
                Text(_currentLyric.isEmpty ? '♪ OMNITUNE ♪' : _currentLyric,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: kAccent.withOpacity(0.55), fontSize: 11, fontFamily: 'Courier')),
                const SizedBox(height: 8),
                _buildSeekBar(),
                _buildTransport(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar() {
    return Row(
      children: [
        Text(_formatTime(_position), style: const TextStyle(color: kAccent, fontSize: 11, fontFamily: 'Courier')),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kAccent,
              inactiveTrackColor: kAccentDim.withOpacity(0.4),
              thumbColor: kAccent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              value: _position.clamp(0.0, _duration),
              max: _duration <= 0 ? 1.0 : _duration,
              onChanged: _player == null ? null : (v) => _seek(v),
            ),
          ),
        ),
        Text(_formatTime(_duration), style: TextStyle(color: kAccent.withOpacity(0.6), fontSize: 11, fontFamily: 'Courier')),
      ],
    );
  }

  Widget _buildTransport() {
    final repeatIcon = _repeat == RepeatMode.one ? Icons.repeat_one : Icons.repeat;
    final repeatColor = _repeat == RepeatMode.off ? Colors.white38 : kAccent;
    return Row(
      children: [
        IconButton(splashRadius: 18, tooltip: 'Shuffle', icon: Icon(Icons.shuffle, size: 18, color: _shuffle ? kAccent : Colors.white38), onPressed: () => setState(() => _shuffle = !_shuffle)),
        IconButton(splashRadius: 18, icon: const Icon(Icons.skip_previous, color: Colors.white), onPressed: _prev),
        IconButton(
          splashRadius: 24,
          iconSize: 44,
          icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: kAccent),
          onPressed: _togglePlay,
        ),
        IconButton(splashRadius: 18, icon: const Icon(Icons.stop, color: Colors.white), onPressed: _stop),
        IconButton(splashRadius: 18, icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: _next),
        IconButton(
          splashRadius: 18,
          tooltip: 'Repeat',
          icon: Icon(repeatIcon, size: 18, color: repeatColor),
          onPressed: () => setState(() {
            _repeat = RepeatMode.values[(_repeat.index + 1) % RepeatMode.values.length];
          }),
        ),
        const SizedBox(width: 8),
        Icon(_volume <= 0.01 ? Icons.volume_off : Icons.volume_up, size: 18, color: kAccent.withOpacity(0.8)),
        SizedBox(
          width: 90,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kAccent,
              inactiveTrackColor: kAccentDim.withOpacity(0.4),
              thumbColor: kAccent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(value: _volume.clamp(0.0, 1.0), onChanged: _player == null ? null : _setVolume),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleBar() {
    Widget toggle(IconData icon, String tip, bool active, VoidCallback onTap) {
      return IconButton(
        splashRadius: 18,
        tooltip: tip,
        icon: Icon(icon, size: 20, color: active ? kAccent : Colors.white54),
        onPressed: onTap,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(6), border: Border.all(color: kPanelBorder)),
      child: Row(
        children: [
          toggle(Icons.library_music, 'Library', _showPlaylist, () => setState(() => _showPlaylist = !_showPlaylist)),
          toggle(Icons.cloud, 'Online (Audius)', _showOnline, () => setState(() => _showOnline = !_showOnline)),
          toggle(Icons.equalizer, 'Equalizer', _showEqualizer, () => setState(() => _showEqualizer = !_showEqualizer)),
          toggle(Icons.lyrics, 'Floating lyrics', _showFloatingLyrics, () => setState(() => _showFloatingLyrics = !_showFloatingLyrics)),
          const VerticalDivider(width: 12, indent: 8, endIndent: 8, color: kPanelBorder),
          IconButton(splashRadius: 18, tooltip: 'Add folder', icon: const Icon(Icons.create_new_folder_outlined, size: 20, color: Colors.white70), onPressed: _scanning ? null : _pickAndScanFolder),
          IconButton(splashRadius: 18, tooltip: 'Sync to cloud', icon: const Icon(Icons.cloud_upload_outlined, size: 20, color: Colors.white70), onPressed: _syncToCloud),
          IconButton(splashRadius: 18, tooltip: 'Load from cloud', icon: const Icon(Icons.cloud_download_outlined, size: 20, color: Colors.white70), onPressed: _loadFromCloud),
          const Spacer(),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kAccent)),
            ),
        ],
      ),
    );
  }

  Widget _buildPanels() {
    final panels = <Widget>[];
    if (_showPlaylist) panels.add(Expanded(flex: 3, child: _buildPlaylistPanel()));
    if (_showOnline) panels.add(Expanded(flex: 3, child: _buildOnlinePanel()));
    if (panels.isEmpty && !_showEqualizer) {
      panels.add(const Expanded(child: Center(child: Text('Toggle a panel above to get started', style: TextStyle(color: Colors.white38)))));
    }
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (_showEqualizer) _buildEqualizerPanel(),
              if (_showEqualizer && panels.isNotEmpty) const SizedBox(height: 10),
              if (panels.isNotEmpty)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < panels.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        panels[i],
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_showFloatingLyrics) _buildFloatingLyrics(),
      ],
    );
  }

  Widget _panelShell({required String header, Widget? trailing, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: kPanel, border: Border.all(color: kPanelBorder), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(color: Color(0xFF242424), borderRadius: BorderRadius.vertical(top: Radius.circular(7))),
            child: Row(
              children: [
                Text(header, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const Spacer(),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildPlaylistPanel() {
    return _panelShell(
      header: 'LIBRARY (${_playlist.length})',
      child: _playlist.isEmpty
          ? const Center(child: Text('Drag music here or use "Add folder"', style: TextStyle(color: Colors.white38, fontSize: 12)))
          : ListView.builder(
              itemCount: _playlist.length,
              itemBuilder: (context, index) {
                final item = _playlist[index];
                final bool isSelected = _currentIndex == index;
                final String rawTitle = (item['title'] as String?) ?? '';
                final String displayTitle = rawTitle.isNotEmpty ? rawTitle : (item['fileName'] ?? '');
                final String artist = (item['artist'] as String?) ?? '';
                final double dur = (item['duration'] as num?)?.toDouble() ?? 0.0;
                return Material(
                  color: isSelected ? kAccent.withOpacity(0.08) : Colors.transparent,
                  child: ListTile(
                    dense: true,
                    leading: Icon(isSelected && _isPlaying ? Icons.volume_up : Icons.music_note, size: 18, color: isSelected ? kAccent : Colors.white38),
                    title: Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isSelected ? kAccent : Colors.white, fontSize: 13)),
                    subtitle: artist.isEmpty ? null : Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    trailing: dur > 0 ? Text(_formatTime(dur), style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Courier')) : null,
                    onTap: () => _playTrackAt(index),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildOnlinePanel() {
    return _panelShell(
      header: 'ONLINE · AUDIUS',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search millions of tracks...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      isDense: true,
                      filled: true,
                      fillColor: kBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _searchOnline(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(icon: const Icon(Icons.search, color: kAccent), onPressed: _searchOnline),
              ],
            ),
          ),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator(color: kAccent))
                : _searchResults.isEmpty
                    ? const Center(child: Text('Search to stream from Audius', style: TextStyle(color: Colors.white38, fontSize: 12)))
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final t = _searchResults[index];
                          return ListTile(
                            dense: true,
                            leading: t.artworkUrl.isEmpty
                                ? const Icon(Icons.cloud_queue, size: 20, color: Colors.white38)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: Image.network(t.artworkUrl, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.cloud_queue, size: 20, color: Colors.white38)),
                                  ),
                            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            subtitle: t.artist.isEmpty ? null : Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            trailing: t.duration > 0 ? Text(_formatTime(t.duration.toDouble()), style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Courier')) : null,
                            onTap: () => _playOnline(t),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEqualizerPanel() {
    return Container(
      height: 168,
      decoration: BoxDecoration(color: kPanel, border: Border.all(color: kPanelBorder), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(color: Color(0xFF242424), borderRadius: BorderRadius.vertical(top: Radius.circular(7))),
            child: Row(
              children: [
                const Text('EQUALIZER', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const Spacer(),
                DropdownButton<String>(
                  value: _eqPreset,
                  dropdownColor: kPanel,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(color: kAccent, fontSize: 12),
                  items: [
                    // Include the current label even if it's the synthetic
                    // 'Custom' state so DropdownButton's value stays valid.
                    ...kEqPresets.keys,
                    if (!kEqPresets.containsKey(_eqPreset)) _eqPreset,
                  ].map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                  onChanged: (v) { if (v != null && kEqPresets.containsKey(v)) _applyEqPreset(v); },
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: List.generate(10, (index) {
                  final freq = kEqFreqs[index];
                  return Expanded(
                    child: Column(
                      children: [
                        Text('${_eqGains[index].toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, color: Colors.white38)),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: kAccent,
                                inactiveTrackColor: kAccentDim.withOpacity(0.4),
                                thumbColor: kAccent,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                              ),
                              child: Slider(
                                value: _eqGains[index],
                                min: -12.0,
                                max: 12.0,
                                onChanged: (v) {
                                  setState(() {
                                    _eqGains[index] = v;
                                    _eqPreset = 'Custom';
                                  });
                                  _player?.setEqBandGain(index, v);
                                },
                              ),
                            ),
                          ),
                        ),
                        Text(freq < 1000 ? '$freq' : '${freq ~/ 1000}k', style: const TextStyle(fontSize: 9, color: kAccent)),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingLyrics() {
    return Positioned(
      left: _lyricsOffset.dx,
      top: _lyricsOffset.dy,
      child: GestureDetector(
        onPanUpdate: (details) => setState(() => _lyricsOffset += details.delta),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.78),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kAccent.withOpacity(0.5)),
          ),
          child: Text(
            _currentLyric.isEmpty ? 'OmniTune TT Next' : _currentLyric,
            style: const TextStyle(color: kAccent, fontSize: 26, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 6)]),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 24,
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(_libReady ? Icons.check_circle : Icons.error_outline, size: 12, color: _libReady ? kAccent : Colors.orangeAccent),
          const SizedBox(width: 6),
          Expanded(child: Text(_statusMsg.isEmpty ? (_libReady ? 'Ready' : 'Audio core not loaded') : _statusMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11))),
        ],
      ),
    );
  }
}
