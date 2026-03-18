import 'dart:async';
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

  Future<void> _scanDirectory() async {
    if (_player == null) return;
    
    // For demo, we scan the current directory or a test music folder
    // In a real app, use a folder picker
    final String scanPath = Directory.current.path; 
    debugPrint('Scanning directory: $scanPath');
    
    final files = _player!.scanDirectory(scanPath);
    debugPrint('Found ${files.length} files');

    for (var file in files) {
      await _cache.insertFile({
        'path': file.path,
        'fileName': file.fileName,
        'title': file.fileName, // Placeholder
        'artist': 'Unknown',
        'album': 'Unknown',
        'duration': 0.0,
      });
    }

    _loadPlaylist();
  }

  void _startUpdateTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_player != null && _player!.isPlaying()) {
        setState(() {
          _position = _player!.getPosition();
          _duration = _player!.getDuration();
          if (_duration <= 0) _duration = 1.0;
          if (_position > _duration) _position = _duration;
        });
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
    });
  }

  void _loadFile(String path) {
    if (_player == null) return;
    if (_player!.load(path)) {
      _togglePlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.music_note, size: 80, color: Colors.blue),
                  const SizedBox(height: 10),
                  Text(
                    _isPlaying ? 'Playing' : 'Paused',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Slider(
                    value: _position.clamp(0.0, _duration),
                    max: _duration,
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
                        icon: const Icon(Icons.stop),
                        onPressed: _player != null ? _stop : null,
                      ),
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: _player != null ? _togglePlay : null,
                        iconSize: 48,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
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
