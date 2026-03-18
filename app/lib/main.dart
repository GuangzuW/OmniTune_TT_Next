import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:audio_service/audio_service.dart';
import 'audio_player_ffi.dart';
import 'metadata_cache.dart';
import 'tray_service.dart';
import 'background_audio.dart';

late BackgroundAudioHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
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

class _PlayerHomePageState extends State<PlayerHomePage> {
  AudioPlayerFFI? _player;
  bool _isPlaying = false;
  double _position = 0.0;
  double _duration = 1.0;
  Timer? _timer;
  final MetadataCache _cache = MetadataCache();
  List<Map<String, dynamic>> _playlist = [];
  List<LyricLine> _lyrics = [];
  String _currentLyric = "";
  final List<double> _eqGains = List.filled(10, 0.0);
  String _currentTitle = "No song loaded";
  bool _showPlaylist = true;
  bool _showEqualizer = false;
  late TrayService _trayService;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    _trayService = TrayService(
      onPlayPause: _togglePlay,
      onNext: () {},
      onPrev: () {},
      onQuit: () => exit(0),
    );
    await _trayService.init();

    if (!kIsWeb) {
      try {
        _player = AudioPlayerFFI();
        _audioHandler = await AudioService.init(
          builder: () => BackgroundAudioHandler(_player!),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.omnitune.app.channel.audio',
            androidNotificationChannelName: 'Music Playback',
            androidNotificationOngoing: true,
          ),
        );
        _startUpdateTimer();
        _loadPlaylist();
      } catch (e) {
        debugPrint('Failed to initialize Services: $e');
      }
    }
  }

  Future<void> _loadPlaylist() async {
    final files = await _cache.getFiles();
    setState(() {
      _playlist = files;
    });
  }

  void _updateCurrentLyric() {
    if (_lyrics.isEmpty) {
      if (_currentLyric != "") setState(() => _currentLyric = "");
      return;
    }
    String found = "";
    for (var i = 0; i < _lyrics.length; i++) {
      if (_position >= _lyrics[i].timestamp) found = _lyrics[i].text;
      else break;
    }
    if (_currentLyric != found) setState(() => _currentLyric = found);
  }

  Future<void> _scanDirectory() async {
    if (_player == null) return;
    final String scanPath = Directory.current.path; 
    final files = _player!.scanDirectory(scanPath);
    for (var file in files) {
      await _cache.insertFile({
        'path': file.path,
        'fileName': file.fileName,
        'title': file.fileName, 
        'artist': 'Unknown',
        'album': 'Unknown',
        'duration': 0.0,
      });
    }
    _loadPlaylist();
  }

  void _startUpdateTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_player != null && _player!.isPlaying()) {
        setState(() {
          _position = _player!.getPosition();
          _duration = _player!.getDuration();
          if (_duration <= 0) _duration = 1.0;
          if (_position > _duration) _position = _duration;
        });
        _updateCurrentLyric();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_player == null) return;
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

  Future<void> _loadLyrics(String musicPath) async {
    final lrcPath = musicPath.replaceAll(RegExp(r'\.(mp3|flac|ape|wav|ogg)$'), '.lrc');
    final lrcFile = File(lrcPath);
    if (await lrcFile.exists()) {
      final content = await lrcFile.readAsString();
      setState(() => _lyrics = _player!.parseLyrics(content));
    } else {
      setState(() {
        _lyrics = [];
        _currentLyric = "";
      });
    }
  }

  void _loadFile(String path, String fileName) {
    if (_player == null) return;
    if (_player!.load(path)) {
      setState(() => _currentTitle = fileName);
      _loadLyrics(path);
      _audioHandler.updateMetadata(fileName, 'Unknown', Duration(seconds: _player!.getDuration().toInt()));
      if (!_isPlaying) _togglePlay();
    }
  }

  String _formatTime(double seconds) {
    final int minutes = (seconds / 60).floor();
    final int remainingSeconds = (seconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('OmniTune TT Next', style: TextStyle(color: Colors.white, fontSize: 14)),
        actions: [
          IconButton(icon: Icon(_showEqualizer ? Icons.equalizer : Icons.equalizer_outlined), onPressed: () => setState(() => _showEqualizer = !_showEqualizer)),
          IconButton(icon: Icon(_showPlaylist ? Icons.list : Icons.list_outlined), onPressed: () => setState(() => _showPlaylist = !_showPlaylist)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _scanDirectory),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Player Window
          Container(
            width: 320,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey[800]!), color: Colors.black),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LCD Display
                Container(
                  height: 120,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.greenAccent, width: 2)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatTime(_position), style: const TextStyle(color: Colors.greenAccent, fontSize: 40, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('KBPS: 320', style: TextStyle(color: Colors.greenAccent.withOpacity(0.7), fontSize: 10)),
                              Text('KHZ: 44.1', style: TextStyle(color: Colors.greenAccent.withOpacity(0.7), fontSize: 10)),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(_currentTitle, style: const TextStyle(color: Colors.greenAccent, fontSize: 12, overflow: TextOverflow.ellipsis)),
                      const SizedBox(height: 5),
                      Text(_currentLyric.isEmpty ? "OMNITUNE TT NEXT" : _currentLyric.toUpperCase(), style: const TextStyle(color: Colors.greenAccent, fontSize: 10, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Visualization / Progress
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                  child: Slider(
                    value: _position.clamp(0.0, _duration),
                    max: _duration,
                    activeColor: Colors.greenAccent,
                    onChanged: (v) {
                      setState(() => _position = v);
                      _audioHandler.seek(Duration(milliseconds: (v * 1000).toInt()));
                    },
                  ),
                ),
                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white), onPressed: () {}),
                    IconButton(icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.greenAccent), onPressed: _togglePlay, iconSize: 48),
                    IconButton(icon: const Icon(Icons.stop, color: Colors.white), onPressed: _stop),
                    IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: () {}),
                  ],
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _showEqualizer ? 100 : 0,
                  curve: Curves.easeInOut,
                  child: _showEqualizer ? Column(
                    children: [
                      const Divider(color: Colors.greenAccent),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 10,
                          itemBuilder: (context, index) {
                            final freqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
                            return Column(
                              children: [
                                Expanded(
                                  child: RotatedBox(quarterTurns: 3, child: Slider(
                                    value: _eqGains[index], min: -12.0, max: 12.0, activeColor: Colors.greenAccent,
                                    onChanged: (v) {
                                      setState(() => _eqGains[index] = v);
                                      _player?.setEqBandGain(index, v);
                                    },
                                  )),
                                ),
                                Text("${freqs[index] < 1000 ? freqs[index] : '${freqs[index]~/1000}k'}", style: const TextStyle(fontSize: 8, color: Colors.greenAccent)),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ) : null,
                )
              ],
            ),
          ),
          // Detachable Playlist Panel
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _showPlaylist ? 400 : 0,
            margin: EdgeInsets.only(left: _showPlaylist ? 8 : 0),
            decoration: BoxDecoration(color: Colors.black, border: Border.all(color: _showPlaylist ? Colors.grey[800]! : Colors.transparent)),
            child: _showPlaylist ? Column(
              children: [
                Container(padding: const EdgeInsets.all(8), color: Colors.grey[900], width: double.infinity, child: const Text('PLAYLIST', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(
                  child: _playlist.isEmpty
                      ? const Center(child: Text('Playlist empty', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _playlist.length,
                          itemBuilder: (context, index) {
                            final item = _playlist[index];
                            final bool isSelected = _currentTitle == item['fileName'];
                            return ListTile(
                              dense: true,
                              leading: Icon(Icons.music_note, size: 16, color: isSelected ? Colors.greenAccent : Colors.grey),
                              title: Text(item['fileName'], style: TextStyle(color: isSelected ? Colors.greenAccent : Colors.white, fontSize: 12)),
                              onTap: () => _loadFile(item['path'], item['fileName']),
                            );
                          },
                        ),
                ),
              ],
            ) : null,
          ),
        ],
      ),
    );
  }
}
