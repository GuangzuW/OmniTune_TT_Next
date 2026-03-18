import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// FFI Signatures
typedef AudioPlayerCreateNative = ffi.Pointer<ffi.Void> Function();
typedef AudioPlayerCreate = ffi.Pointer<ffi.Void> Function();

typedef AudioPlayerDestroyNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerDestroy = void Function(ffi.Pointer<ffi.Void>);

typedef AudioPlayerLoadNative = ffi.Bool Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>);
typedef AudioPlayerLoad = bool Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>);

typedef AudioPlayerPlayNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerPlay = void Function(ffi.Pointer<ffi.Void>);

typedef AudioPlayerPauseNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerPause = void Function(ffi.Pointer<ffi.Void>);

typedef AudioPlayerStopNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerStop = void Function(ffi.Pointer<ffi.Void>);

typedef AudioPlayerSeekToNative = ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Float);
typedef AudioPlayerSeekTo = void Function(ffi.Pointer<ffi.Void>, double);

typedef AudioPlayerGetPositionNative = ffi.Float Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerGetPosition = double Function(ffi.Pointer<ffi.Void>);

typedef AudioPlayerGetDurationNative = ffi.Float Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerGetDuration = double Function(ffi.Pointer<ffi.Void>);

typedef AudioPlayerIsPlayingNative = ffi.Bool Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerIsPlaying = bool Function(ffi.Pointer<ffi.Void>);

// Scanner Signatures
typedef FileScannerScanNative = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>);
typedef FileScannerScan = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>);

typedef ScanResultGetCountNative = ffi.Int32 Function(ffi.Pointer<ffi.Void>);
typedef ScanResultGetCount = int Function(ffi.Pointer<ffi.Void>);

typedef ScanResultGetPathNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, ffi.Int32);
typedef ScanResultGetPath = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, int);

typedef ScanResultGetFileNameNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, ffi.Int32);
typedef ScanResultGetFileName = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, int);

typedef ScanResultDestroyNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef ScanResultDestroy = void Function(ffi.Pointer<ffi.Void>);

class AudioFileInfo {
  final String path;
  final String fileName;
  AudioFileInfo(this.path, this.fileName);
}

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

  late FileScannerScan _scan;
  late ScanResultGetCount _getCount;
  late ScanResultGetPath _getPath;
  late ScanResultGetFileName _getFileName;
  late ScanResultDestroy _destroyScanResult;

  AudioPlayerFFI() {
    _lib = _loadLibrary();
    
    _create = _lib.lookupFunction<AudioPlayerCreateNative, AudioPlayerCreate>('AudioPlayer_create');
    _destroy = _lib.lookupFunction<AudioPlayerDestroyNative, AudioPlayerDestroy>('AudioPlayer_destroy');
    _load = _lib.lookupFunction<AudioPlayerLoadNative, AudioPlayerLoad>('AudioPlayer_load');
    _play = _lib.lookupFunction<AudioPlayerPlayNative, AudioPlayerPlay>('AudioPlayer_play');
    _pause = _lib.lookupFunction<AudioPlayerPauseNative, AudioPlayerPause>('AudioPlayer_pause');
    _stop = _lib.lookupFunction<AudioPlayerStopNative, AudioPlayerStop>('AudioPlayer_stop');
    _seekTo = _lib.lookupFunction<AudioPlayerSeekToNative, AudioPlayerSeekTo>('AudioPlayer_seekTo');
    _getPosition = _lib.lookupFunction<AudioPlayerGetPositionNative, AudioPlayerGetPosition>('AudioPlayer_getPosition');
    _getDuration = _lib.lookupFunction<AudioPlayerGetDurationNative, AudioPlayerGetDuration>('AudioPlayer_getDuration');
    _isPlaying = _lib.lookupFunction<AudioPlayerIsPlayingNative, AudioPlayerIsPlaying>('AudioPlayer_isPlaying');

    _scan = _lib.lookupFunction<FileScannerScanNative, FileScannerScan>('FileScanner_scan');
    _getCount = _lib.lookupFunction<ScanResultGetCountNative, ScanResultGetCount>('ScanResult_getCount');
    _getPath = _lib.lookupFunction<ScanResultGetPathNative, ScanResultGetPath>('ScanResult_getPath');
    _getFileName = _lib.lookupFunction<ScanResultGetFileNameNative, ScanResultGetFileName>('ScanResult_getFileName');
    _destroyScanResult = _lib.lookupFunction<ScanResultDestroyNative, ScanResultDestroy>('ScanResult_destroy');

    _player = _create();
  }

  ffi.DynamicLibrary _loadLibrary() {
    if (Platform.isMacOS) {
      // Relative to project root if running from flutter run
      final libraryPath = path.join(Directory.current.path, 'core', 'build', 'libTTPlayerCore.dylib');
      if (File(libraryPath).existsSync()) {
        return ffi.DynamicLibrary.open(libraryPath);
      }
      // Try bundle path for macOS app
      return ffi.DynamicLibrary.open('libTTPlayerCore.dylib');
    }
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('TTPlayerCore.dll');
    }
    if (Platform.isLinux) {
      return ffi.DynamicLibrary.open('libTTPlayerCore.so');
    }
    throw UnsupportedError('Platform not supported: ${Platform.operatingSystem}');
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

  List<AudioFileInfo> scanDirectory(String dirPath) {
    final pathPtr = dirPath.toNativeUtf8();
    final resultPtr = _scan(pathPtr);
    malloc.free(pathPtr);

    if (resultPtr == ffi.nullptr) return [];

    final count = _getCount(resultPtr);
    final List<AudioFileInfo> files = [];

    for (var i = 0; i < count; i++) {
      final pathPtr = _getPath(resultPtr, i);
      final fileNamePtr = _getFileName(resultPtr, i);
      
      files.add(AudioFileInfo(
        pathPtr.toDartString(),
        fileNamePtr.toDartString(),
      ));
    }

    _destroyScanResult(resultPtr);
    return files;
  }
}
