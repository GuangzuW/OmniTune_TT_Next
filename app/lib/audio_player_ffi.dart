import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// --- FFI Signatures ---

// Audio Player
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
typedef AudioPlayerSetEqBandGainNative = ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Float);
typedef AudioPlayerSetEqBandGain = void Function(ffi.Pointer<ffi.Void>, int, double);
typedef AudioPlayerSetVolumeNative = ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Float);
typedef AudioPlayerSetVolume = void Function(ffi.Pointer<ffi.Void>, double);
typedef AudioPlayerGetVolumeNative = ffi.Float Function(ffi.Pointer<ffi.Void>);
typedef AudioPlayerGetVolume = double Function(ffi.Pointer<ffi.Void>);

// Scanner
typedef FileScannerScanNative = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>);
typedef FileScannerScan = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>);
typedef ScanResultGetCountNative = ffi.Int32 Function(ffi.Pointer<ffi.Void>);
typedef ScanResultGetCount = int Function(ffi.Pointer<ffi.Void>);
typedef ScanResultGetPathNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, ffi.Int32);
typedef ScanResultGetPath = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, int);
typedef ScanResultGetFileNameNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, ffi.Int32);
typedef ScanResultGetFileName = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, int);
typedef ScanResultGetAlbumArtPathNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, ffi.Int32);
typedef ScanResultGetAlbumArtPath = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, int);
typedef ScanResultGetTitleNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, ffi.Int32);
typedef ScanResultGetTitle = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, int);
typedef ScanResultGetArtistNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, ffi.Int32);
typedef ScanResultGetArtist = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, int);
typedef ScanResultGetAlbumNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, ffi.Int32);
typedef ScanResultGetAlbum = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, int);
typedef ScanResultGetDurationNative = ffi.Float Function(ffi.Pointer<ffi.Void>, ffi.Int32);
typedef ScanResultGetDuration = double Function(ffi.Pointer<ffi.Void>, int);
typedef ScanResultDestroyNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef ScanResultDestroy = void Function(ffi.Pointer<ffi.Void>);

// Lyrics
typedef LyricsParserParseNative = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>);
typedef LyricsParserParse = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>);
typedef LyricsResultGetCountNative = ffi.Int32 Function(ffi.Pointer<ffi.Void>);
typedef LyricsResultGetCount = int Function(ffi.Pointer<ffi.Void>);
typedef LyricsResultGetTimestampNative = ffi.Float Function(ffi.Pointer<ffi.Void>, ffi.Int32);
typedef LyricsResultGetTimestamp = double Function(ffi.Pointer<ffi.Void>, int);
typedef LyricsResultGetTextNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, ffi.Int32);
typedef LyricsResultGetText = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, int);
typedef LyricsResultDestroyNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef LyricsResultDestroy = void Function(ffi.Pointer<ffi.Void>);

class AudioFileInfo {
  final String path;
  final String fileName;
  final String albumArtPath;
  final String title;
  final String artist;
  final String album;
  final double duration;
  AudioFileInfo(
    this.path,
    this.fileName,
    this.albumArtPath, {
    this.title = "",
    this.artist = "",
    this.album = "",
    this.duration = 0.0,
  });
}

class LyricLine {
  final double timestamp;
  final String text;
  LyricLine(this.timestamp, this.text);
}

class AudioPlayerFFI {
  late ffi.DynamicLibrary _lib;
  late ffi.Pointer<ffi.Void> _player;

  // Audio Player methods
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
  late AudioPlayerSetEqBandGain _setEqBandGain;
  late AudioPlayerSetVolume _setVolume;
  late AudioPlayerGetVolume _getVolume;

  // Scanner methods
  late FileScannerScan _scan;
  late ScanResultGetCount _getScanCount;
  late ScanResultGetPath _getScanPath;
  late ScanResultGetFileName _getScanFileName;
  late ScanResultGetAlbumArtPath _getScanAlbumArtPath;
  late ScanResultGetTitle _getScanTitle;
  late ScanResultGetArtist _getScanArtist;
  late ScanResultGetAlbum _getScanAlbum;
  late ScanResultGetDuration _getScanDuration;
  late ScanResultDestroy _destroyScanResult;

  // Lyrics methods
  late LyricsParserParse _parseLyrics;
  late LyricsResultGetCount _getLyricsCount;
  late LyricsResultGetTimestamp _getLyricsTimestamp;
  late LyricsResultGetText _getLyricsText;
  late LyricsResultDestroy _destroyLyricsResult;

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
    _setEqBandGain = _lib.lookupFunction<AudioPlayerSetEqBandGainNative, AudioPlayerSetEqBandGain>('AudioPlayer_setEqBandGain');
    _setVolume = _lib.lookupFunction<AudioPlayerSetVolumeNative, AudioPlayerSetVolume>('AudioPlayer_setVolume');
    _getVolume = _lib.lookupFunction<AudioPlayerGetVolumeNative, AudioPlayerGetVolume>('AudioPlayer_getVolume');

    _scan = _lib.lookupFunction<FileScannerScanNative, FileScannerScan>('FileScanner_scan');
    _getScanCount = _lib.lookupFunction<ScanResultGetCountNative, ScanResultGetCount>('ScanResult_getCount');
    _getScanPath = _lib.lookupFunction<ScanResultGetPathNative, ScanResultGetPath>('ScanResult_getPath');
    _getScanFileName = _lib.lookupFunction<ScanResultGetFileNameNative, ScanResultGetFileName>('ScanResult_getFileName');
    _getScanAlbumArtPath = _lib.lookupFunction<ScanResultGetAlbumArtPathNative, ScanResultGetAlbumArtPath>('ScanResult_getAlbumArtPath');
    _getScanTitle = _lib.lookupFunction<ScanResultGetTitleNative, ScanResultGetTitle>('ScanResult_getTitle');
    _getScanArtist = _lib.lookupFunction<ScanResultGetArtistNative, ScanResultGetArtist>('ScanResult_getArtist');
    _getScanAlbum = _lib.lookupFunction<ScanResultGetAlbumNative, ScanResultGetAlbum>('ScanResult_getAlbum');
    _getScanDuration = _lib.lookupFunction<ScanResultGetDurationNative, ScanResultGetDuration>('ScanResult_getDuration');
    _destroyScanResult = _lib.lookupFunction<ScanResultDestroyNative, ScanResultDestroy>('ScanResult_destroy');

    _parseLyrics = _lib.lookupFunction<LyricsParserParseNative, LyricsParserParse>('LyricsParser_parse');
    _getLyricsCount = _lib.lookupFunction<LyricsResultGetCountNative, LyricsResultGetCount>('LyricsResult_getCount');
    _getLyricsTimestamp = _lib.lookupFunction<LyricsResultGetTimestampNative, LyricsResultGetTimestamp>('LyricsResult_getTimestamp');
    _getLyricsText = _lib.lookupFunction<LyricsResultGetTextNative, LyricsResultGetText>('LyricsResult_getText');
    _destroyLyricsResult = _lib.lookupFunction<LyricsResultDestroyNative, LyricsResultDestroy>('LyricsResult_destroy');

    _player = _create();
  }

  ffi.DynamicLibrary _loadLibrary() {
    // iOS links the core statically into the app binary (see TTPlayerCore.podspec),
    // so its symbols live in the running process.
    if (Platform.isIOS) {
      return ffi.DynamicLibrary.process();
    }
    // Android bundles libTTPlayerCore.so in the APK; the loader finds it by name.
    if (Platform.isAndroid) {
      return ffi.DynamicLibrary.open('libTTPlayerCore.so');
    }

    final String libName;
    if (Platform.isMacOS) {
      libName = 'libTTPlayerCore.dylib';
    } else if (Platform.isWindows) {
      libName = 'TTPlayerCore.dll';
    } else if (Platform.isLinux) {
      libName = 'libTTPlayerCore.so';
    } else {
      throw UnsupportedError('Platform not supported: ${Platform.operatingSystem}');
    }

    // Candidate locations, in priority order:
    //  1. next to the running executable (bundled release builds)
    //  2. common CMake output dirs relative to the working directory (dev runs)
    //  3. bare name (rely on the OS loader search path)
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final cwd = Directory.current.path;
    final candidates = <String>[
      path.join(exeDir, libName),
      path.join(exeDir, '..', 'Frameworks', libName), // macOS .app bundle layout
      path.join(cwd, libName),
      path.join(cwd, 'core', 'build', libName),
      path.join(cwd, 'core', 'build', 'Release', libName), // MSVC multi-config
      path.join(cwd, '..', 'core', 'build', libName),
      path.join(cwd, '..', 'core', 'build', 'Release', libName),
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) {
        return ffi.DynamicLibrary.open(c);
      }
    }
    return ffi.DynamicLibrary.open(libName);
  }

  void dispose() => _destroy(_player);

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
  void setEqBandGain(int bandIndex, double gain) => _setEqBandGain(_player, bandIndex, gain);
  void setVolume(double volume) => _setVolume(_player, volume);
  double getVolume() => _getVolume(_player);

  List<AudioFileInfo> scanDirectory(String dirPath) {
    final pathPtr = dirPath.toNativeUtf8();
    final resultPtr = _scan(pathPtr);
    malloc.free(pathPtr);
    if (resultPtr == ffi.nullptr) return [];
    final count = _getScanCount(resultPtr);
    final List<AudioFileInfo> files = [];
    for (var i = 0; i < count; i++) {
      final artPathPtr = _getScanAlbumArtPath(resultPtr, i);
      final titlePtr = _getScanTitle(resultPtr, i);
      final artistPtr = _getScanArtist(resultPtr, i);
      final albumPtr = _getScanAlbum(resultPtr, i);
      files.add(AudioFileInfo(
        _getScanPath(resultPtr, i).toDartString(),
        _getScanFileName(resultPtr, i).toDartString(),
        artPathPtr == ffi.nullptr ? "" : artPathPtr.toDartString(),
        title: titlePtr == ffi.nullptr ? "" : titlePtr.toDartString(),
        artist: artistPtr == ffi.nullptr ? "" : artistPtr.toDartString(),
        album: albumPtr == ffi.nullptr ? "" : albumPtr.toDartString(),
        duration: _getScanDuration(resultPtr, i),
      ));
    }
    _destroyScanResult(resultPtr);
    return files;
  }

  List<LyricLine> parseLyrics(String lrcContent) {
    final lrcPtr = lrcContent.toNativeUtf8();
    final resultPtr = _parseLyrics(lrcPtr);
    malloc.free(lrcPtr);
    if (resultPtr == ffi.nullptr) return [];
    final count = _getLyricsCount(resultPtr);
    final List<LyricLine> lyrics = [];
    for (var i = 0; i < count; i++) {
      lyrics.add(LyricLine(
        _getLyricsTimestamp(resultPtr, i),
        _getLyricsText(resultPtr, i).toDartString(),
      ));
    }
    _destroyLyricsResult(resultPtr);
    return lyrics;
  }
}
