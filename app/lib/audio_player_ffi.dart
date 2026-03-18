import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

// Type definitions for C functions
typedef AudioPlayerCreateC = ffi.Pointer<ffi.Void> Function();
typedef AudioPlayerDestroyC = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerLoadC = ffi.Bool Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>);
typedef AudioPlayerPlayC = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerPauseC = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerStopC = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerSeekToC = ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Float);
typedef AudioPlayerGetPositionC = ffi.Float Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerGetDurationC = ffi.Float Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerIsPlayingC = ffi.Bool Function(ffi.Pointer<ffi.Void>);

// Dart function signatures
typedef AudioPlayerCreate = ffi.Pointer<ffi.Void> Function();
typedef AudioPlayerDestroy = void Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerLoad = bool Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>);
typedef AudioPlayerPlay = void Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerPause = void Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerStop = void Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerSeekTo = void Function(ffi.Pointer<ffi.Void>, double);
typedef AudioPlayerGetPosition = double Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerGetDuration = double Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerIsPlaying = bool Function(ffi.Pointer<ffi.Void>);

class AudioPlayerFFI {
  late ffi.DynamicLibrary _lib;
  late ffi.Pointer<ffi.Void> _player;

  late AudioPlayerCreate _create;
  late AudioPlayerDestroy _destroy;
  late AudioPlayerLoad _load;
  late AudioPlayerPlay _play;
  late AudioPlayerPause _pause;
  late AudioPlayerStop _stop;
  late AudioPlayerSeekTo _seekTo;
  late AudioPlayerGetPosition _getPosition;
  late AudioPlayerGetDuration _getDuration;
  late AudioPlayerIsPlaying _isPlaying;

  AudioPlayerFFI() {
    _lib = _loadLibrary();
    _create = _lib.lookupFunction<AudioPlayerCreateC, AudioPlayerCreate>('AudioPlayer_create');
    _destroy = _lib.lookupFunction<AudioPlayerDestroyC, AudioPlayerDestroy>('AudioPlayer_destroy');
    _load = _lib.lookupFunction<AudioPlayerLoadC, AudioPlayerLoad>('AudioPlayer_load');
    _play = _lib.lookupFunction<AudioPlayerPlayC, AudioPlayerPlay>('AudioPlayer_play');
    _pause = _lib.lookupFunction<AudioPlayerPauseC, AudioPlayerPause>('AudioPlayer_pause');
    _stop = _lib.lookupFunction<AudioPlayerStopC, AudioPlayerStop>('AudioPlayer_stop');
    _seekTo = _lib.lookupFunction<AudioPlayerSeekToC, AudioPlayerSeekTo>('AudioPlayer_seekTo');
    _getPosition = _lib.lookupFunction<AudioPlayerGetPositionC, AudioPlayerGetPosition>('AudioPlayer_getPosition');
    _getDuration = _lib.lookupFunction<AudioPlayerGetDurationC, AudioPlayerGetDuration>('AudioPlayer_getDuration');
    _isPlaying = _lib.lookupFunction<AudioPlayerIsPlayingC, AudioPlayerIsPlaying>('AudioPlayer_isPlaying');

    _player = _create();
  }

  ffi.DynamicLibrary _loadLibrary() {
    if (Platform.isMacOS) {
      // In development, we can point to the build folder
      // In production, it should be in the app bundle
      final path = '${Directory.current.parent.path}/core/build/libTTPlayerCore.dylib';
      return ffi.DynamicLibrary.open(path);
    } else if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('TTPlayerCore.dll');
    } else if (Platform.isLinux) {
      return ffi.DynamicLibrary.open('libTTPlayerCore.so');
    }
    throw UnsupportedError('Platform not supported');
  }

  void dispose() {
    _destroy(_player);
  }

  bool load(String filePath) {
    final pathPtr = filePath.toNativeUtf8();
    final result = _load(_player, pathPtr);
    malloc.free(pathPtr);
    return result;
  }

  void play() => _play(_player);
  void pause() => _pause(_player);
  void stop() => _stop(_player);
  void seekTo(double position) => _seekTo(_player, position);
  double getPosition() => _getPosition(_player);
  double getDuration() => _getDuration(_player);
  bool isPlaying() => _isPlaying(_player);
}
