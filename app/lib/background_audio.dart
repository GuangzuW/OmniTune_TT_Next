import 'package:audio_service/audio_service.dart';
import 'audio_player_ffi.dart';

class BackgroundAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayerFFI _player;

  BackgroundAudioHandler(this._player) {
    _player.isPlaying(); // Ensure player is ready
  }

  @override
  Future<void> play() async {
    _player.play();
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      controls: [MediaControl.pause, MediaControl.stop],
      systemActions: {MediaAction.seek},
    ));
  }

  @override
  Future<void> pause() async {
    _player.pause();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: [MediaControl.play, MediaControl.stop],
    ));
  }

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
