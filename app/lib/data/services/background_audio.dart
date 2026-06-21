import 'package:audio_service/audio_service.dart';
import 'audio_player_ffi.dart';

class BackgroundAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayerFFI _player;

  // Wired by the UI so OS media controls (lock screen, headset, notification)
  // can drive playlist navigation, which lives in the widget layer.
  void Function()? onNext;
  void Function()? onPrev;

  BackgroundAudioHandler(this._player) {
    _player.isPlaying(); // Ensure player is ready
  }

  @override
  Future<void> play() async {
    _player.play();
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      controls: [MediaControl.skipToPrevious, MediaControl.pause, MediaControl.stop, MediaControl.skipToNext],
      systemActions: {MediaAction.seek},
    ));
  }

  @override
  Future<void> pause() async {
    _player.pause();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: [MediaControl.skipToPrevious, MediaControl.play, MediaControl.stop, MediaControl.skipToNext],
    ));
  }

  @override
  Future<void> skipToNext() async => onNext?.call();

  @override
  Future<void> skipToPrevious() async => onPrev?.call();

  @override
  Future<void> stop() async {
    _player.stop();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }

  @override
  Future<void> seek(Duration position) async {
    _player.seekTo(position.inMilliseconds / 1000.0);
  }

  void updateMetadata(String title, String artist, Duration duration) {
    mediaItem.add(MediaItem(
      id: title,
      album: 'OmniTune',
      title: title,
      artist: artist,
      duration: duration,
    ));
  }
}
