#ifndef AUDIO_PLAYER_C_H
#define AUDIO_PLAYER_C_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void* AudioPlayerPtr;
typedef void* ScanResultPtr;
typedef void* LyricsResultPtr;

// Audio Player
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

// File Scanner
ScanResultPtr FileScanner_scan(const char* dirPath);
int ScanResult_getCount(ScanResultPtr result);
const char* ScanResult_getPath(ScanResultPtr result, int index);
const char* ScanResult_getFileName(ScanResultPtr result, int index);
void ScanResult_destroy(ScanResultPtr result);

// Lyrics Parser
LyricsResultPtr LyricsParser_parse(const char* lrcContent);
int LyricsResult_getCount(LyricsResultPtr result);
float LyricsResult_getTimestamp(LyricsResultPtr result, int index);
const char* LyricsResult_getText(LyricsResultPtr result, int index);
void LyricsResult_destroy(LyricsResultPtr result);

#ifdef __cplusplus
}
#endif

#endif // AUDIO_PLAYER_C_H
