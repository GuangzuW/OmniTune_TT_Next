import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'audio_player_ffi.dart';
import 'metadata_cache.dart';

void main() {
  runApp(const TTPlayerApp());
}

class TTPlayerApp extends StatelessWidget {
  const TTPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniTune TT Next',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      try {
        _player = AudioPlayerFFI();
        _startUpdateTimer();
        _loadPlaylist();
      } catch (e) {
        debugPrint('Failed to initialize AudioPlayerFFI: $e');
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
      if (_currentLyric != "") {
        setState(() {
          _currentLyric = "";
        });
      }
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
    
    if (_currentLyric != found) {
      setState(() {
        _currentLyric = found;
      });
    }
  }

  Future<void> _scanDirectory() async {
    if (_player == null) return;
    
    final String scanPath = Directory.current.path; 
    debugPrint('Scanning directory: $scanPath');
    
    final files = _player!.scanDirectory(scanPath);
    debugPrint('Found ${files.length} files');

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
        _player!.pause();
        _isPlaying = false;
      } else {
        _player!.play();
        _isPlaying = true;
      }
    });
  }

  void _stop() {
    if (_player == null) return;
    _player!.stop();
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
      setState(() {
        _lyrics = _player!.parseLyrics(content);
      });
      debugPrint('Loaded ${_lyrics.length} lyric lines');
    } else {
      setState(() {
        _lyrics = [];
        _currentLyric = "";
      });
      debugPrint('No lyrics found at $lrcPath');
    }
  }

  void _loadFile(String path) {
    if (_player == null) return;
    if (_player!.load(path)) {
      _loadLyrics(path);
      if (!_isPlaying) {
        _togglePlay();
      }
    }
  }

  void _showEqualizer() {
    final List<int> freqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: 400,
              child: Column(
                children: [
                  const Text("10-Band Equalizer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 10,
                      itemBuilder: (context, index) {
                        return Column(
                          children: [
                            Expanded(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Slider(
                                  value: _eqGains[index],
                                  min: -12.0,
                                  max: 12.0,
                                  onChanged: (v) {
                                    setModalState(() {
                                      _eqGains[index] = v;
                                    });
                                    _player?.setEqBandGain(index, v);
                                  },
                                ),
                              ),
                            ),
                            Text("${freqs[index]}Hz", style: const TextStyle(fontSize: 10)),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.equalizer),
            onPressed: _showEqualizer,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanDirectory,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black87,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    _currentLyric.isEmpty ? "OmniTune TT Next" : _currentLyric,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: _position.clamp(0.0, _duration),
                    max: _duration,
                    activeColor: Colors.greenAccent,
                    onChanged: (value) {
                      setState(() {
                        _position = value;
                      });
                      _player?.seekTo(value);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.stop, color: Colors.white),
                        onPressed: _player != null ? _stop : null,
                      ),
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                        onPressed: _player != null ? _togglePlay : null,
                        iconSize: 48,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            flex: 2,
            child: _playlist.isEmpty
                ? const Center(child: Text('No music found. Click refresh to scan.'))
                : ListView.builder(
                    itemCount: _playlist.length,
                    itemBuilder: (context, index) {
                      final item = _playlist[index];
                      return ListTile(
                        leading: const Icon(Icons.audio_file),
                        title: Text(item['fileName']),
                        subtitle: Text(item['path']),
                        onTap: () => _loadFile(item['path']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
