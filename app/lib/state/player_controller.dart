import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/data/models/track.dart';
import 'package:app/data/services/audio_player_ffi.dart';
import 'package:app/data/services/background_audio.dart';
import 'package:app/data/services/remote_api.dart';
import 'package:app/state/providers.dart';

enum RepeatMode { off, all, one }

const List<int> kEqFreqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
const Map<String, List<double>> kEqPresets = {
  'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'Rock': [4, 3, -1, -2, -1, 1, 3, 4, 4, 4],
  'Pop': [-1, 1, 3, 4, 3, 0, -1, -1, -1, -1],
  'Jazz': [3, 2, 1, 2, -1, -1, 0, 1, 2, 3],
  'Bass': [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
  'Vocal': [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1],
};

class PlayerState {
  final List<Track> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool buffering;
  final double position; // seconds
  final double duration; // seconds
  final double volume;
  final bool shuffle;
  final RepeatMode repeat;
  final List<double> eqGains;
  final String eqPreset;
  final String? error;

  const PlayerState({
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.buffering = false,
    this.position = 0,
    this.duration = 0,
    this.volume = 1.0,
    this.shuffle = false,
    this.repeat = RepeatMode.off,
    this.eqGains = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.eqPreset = 'Flat',
    this.error,
  });

  Track? get current =>
      (currentIndex >= 0 && currentIndex < queue.length) ? queue[currentIndex] : null;
  bool get hasTrack => current != null;

  PlayerState copyWith({
    List<Track>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? buffering,
    double? position,
    double? duration,
    double? volume,
    bool? shuffle,
    RepeatMode? repeat,
    List<double>? eqGains,
    String? eqPreset,
    String? error,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      eqGains: eqGains ?? this.eqGains,
      eqPreset: eqPreset ?? this.eqPreset,
      error: error,
    );
  }
}

class PlayerController extends Notifier<PlayerState> {
  AudioPlayerFFI? _engine;
  BackgroundAudioHandler? _handler;
  late ApiClient _api;
  Timer? _timer;
  final Random _rng = Random();

  @override
  PlayerState build() {
    _engine = ref.read(audioEngineProvider);
    _handler = ref.read(audioHandlerProvider);
    _api = ref.read(apiClientProvider);
    _handler?.onNext = () => next();
    _handler?.onPrev = prev;
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    ref.onDispose(() => _timer?.cancel());
    return const PlayerState();
  }

  void _tick() {
    final engine = _engine;
    if (engine == null) return;
    if (engine.isPlaying()) {
      var dur = engine.getDuration();
      if (dur <= 0) dur = 1;
      var pos = engine.getPosition();
      if (pos > dur) pos = dur;
      state = state.copyWith(position: pos, duration: dur, isPlaying: true);
    } else if (state.isPlaying) {
      // Engine stopped while we thought it was playing → track ended.
      if (state.duration > 0 && state.position >= state.duration - 0.6) {
        _onEnded();
      }
    }
  }

  void _onEnded() {
    if (state.repeat == RepeatMode.one && state.currentIndex >= 0) {
      _playAt(state.currentIndex);
    } else {
      next(auto: true);
    }
  }

  /// Replace the queue and start at [startIndex].
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    state = state.copyWith(queue: List.of(tracks));
    await _playAt(startIndex);
  }

  /// Append a track and play it immediately.
  Future<void> playNow(Track track) async {
    final q = List.of(state.queue)..add(track);
    state = state.copyWith(queue: q);
    await _playAt(q.length - 1);
  }

  void enqueue(Track track) =>
      state = state.copyWith(queue: List.of(state.queue)..add(track));

  Future<void> jumpTo(int index) => _playAt(index);

  void reorder(int oldIndex, int newIndex) {
    final q = List.of(state.queue);
    if (oldIndex < 0 || oldIndex >= q.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final item = q.removeAt(oldIndex);
    q.insert(newIndex, item);
    // Keep currentIndex pointing at the same track.
    var current = state.currentIndex;
    if (oldIndex == current) {
      current = newIndex;
    } else if (oldIndex < current && newIndex >= current) {
      current -= 1;
    } else if (oldIndex > current && newIndex <= current) {
      current += 1;
    }
    state = state.copyWith(queue: q, currentIndex: current);
  }

  Future<void> _playAt(int index) async {
    final engine = _engine;
    if (engine == null || index < 0 || index >= state.queue.length) return;
    final track = state.queue[index];
    state = state.copyWith(buffering: true, error: null, currentIndex: index);
    try {
      String path = track.id;
      if (track.isRemote) {
        path = await _api.downloadById(track.id);
      }
      if (!engine.load(path)) {
        state = state.copyWith(buffering: false, error: 'Failed to load "${track.title}"');
        return;
      }
      engine.setVolume(state.volume);
      for (var i = 0; i < state.eqGains.length; i++) {
        engine.setEqBandGain(i, state.eqGains[i]);
      }
      engine.play();
      _handler?.play();
      _handler?.updateMetadata(track.title, track.artist,
          Duration(seconds: engine.getDuration().toInt()));
      state = state.copyWith(
        buffering: false,
        isPlaying: true,
        position: 0,
        duration: engine.getDuration(),
      );
    } catch (e) {
      state = state.copyWith(buffering: false, error: '$e');
    }
  }

  void togglePlay() {
    final engine = _engine;
    if (engine == null || !state.hasTrack) return;
    if (engine.isPlaying()) {
      engine.pause();
      _handler?.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      engine.play();
      _handler?.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  void stop() {
    _engine?.stop();
    _handler?.stop();
    state = state.copyWith(isPlaying: false, position: 0);
  }

  Future<void> next({bool auto = false}) async {
    if (state.queue.isEmpty) return;
    if (state.shuffle && state.queue.length > 1) {
      int idx;
      do {
        idx = _rng.nextInt(state.queue.length);
      } while (idx == state.currentIndex);
      await _playAt(idx);
      return;
    }
    final n = state.currentIndex + 1;
    if (n >= state.queue.length) {
      if (auto && state.repeat == RepeatMode.off) {
        state = state.copyWith(isPlaying: false);
        return;
      }
      await _playAt(0); // wrap (manual, or repeat-all)
    } else {
      await _playAt(n);
    }
  }

  Future<void> prev() async {
    if (state.queue.isEmpty) return;
    // Restart current track if we're more than 3s in (Spotify behaviour).
    if (state.position > 3) {
      seek(0);
      return;
    }
    final start = state.currentIndex < 0 ? 0 : state.currentIndex;
    await _playAt((start - 1 + state.queue.length) % state.queue.length);
  }

  void seek(double seconds) {
    _engine?.seekTo(seconds);
    _handler?.seek(Duration(milliseconds: (seconds * 1000).toInt()));
    state = state.copyWith(position: seconds);
  }

  void setVolume(double v) {
    _engine?.setVolume(v);
    state = state.copyWith(volume: v);
  }

  void toggleShuffle() => state = state.copyWith(shuffle: !state.shuffle);

  void cycleRepeat() => state = state.copyWith(
      repeat: RepeatMode.values[(state.repeat.index + 1) % RepeatMode.values.length]);

  void setEqBand(int band, double gain) {
    _engine?.setEqBandGain(band, gain);
    final gains = List<double>.of(state.eqGains)..[band] = gain;
    state = state.copyWith(eqGains: gains, eqPreset: 'Custom');
  }

  void applyEqPreset(String name) {
    final preset = kEqPresets[name];
    if (preset == null) return;
    for (var i = 0; i < preset.length; i++) {
      _engine?.setEqBandGain(i, preset[i]);
    }
    state = state.copyWith(eqGains: List<double>.of(preset), eqPreset: name);
  }
}

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);
