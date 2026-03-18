import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'audio_player_ffi.dart';

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

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      try {
        _player = AudioPlayerFFI();
        _startUpdateTimer();
      } catch (e) {
        debugPrint('Failed to initialize AudioPlayerFFI: $e');
      }
    }
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

  void _loadFile() {
    // For now, let's just use a hardcoded path or a mock
    // In a real app, we'd use a file picker
    debugPrint('Load file clicked');
    // Example: _player?.load('/path/to/audio.mp3');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.music_note, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              _isPlaying ? 'Playing' : 'Paused',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Slider(
                value: _position.clamp(0.0, _duration),
                max: _duration,
                onChanged: (value) {
                  setState(() {
                    _position = value;
                  });
                  _player?.seekTo(value);
                },
              ),
            ),
            Text(
              '${_position.toStringAsFixed(1)} / ${_duration.toStringAsFixed(1)}s',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _player != null ? _stop : null,
                  iconSize: 48,
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _player != null ? _togglePlay : null,
                  iconSize: 64,
                ),
                IconButton(
                  icon: const Icon(Icons.file_open),
                  onPressed: _loadFile,
                  iconSize: 48,
                ),
              ],
            ),
            if (kIsWeb)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('Web support coming soon via Wasm bindings.'),
              ),
            if (_player == null && !kIsWeb)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('Error: Native library not found.', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
