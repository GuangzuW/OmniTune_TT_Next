#ifndef AUDIO_PLAYER_C_H
#define AUDIO_PLAYER_C_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void* AudioPlayerPtr;

AudioPlayerPtr AudioPlayer_create();
void AudioPlayer_destroy(AudioPlayerPtr player);

bool AudioPlayer_load(AudioPlayerPtr player, const char* filePath);
void AudioPlayer_play(AudioPlayerPtr player);
void AudioPlayer_pause(AudioPlayerPtr player);
void AudioPlayer_stop(AudioPlayerPtr player);
void AudioPlayer_seekTo(AudioPlayerPtr player, float position);
float AudioPlayer_getPosition(AudioPlayerPtr player);
float AudioPlayer_getDuration(AudioPlayerPtr player);
bool AudioPlayer_isPlaying(AudioPlayerPtr player);

#ifdef __cplusplus
}
#endif

#endif // AUDIO_PLAYER_C_H
