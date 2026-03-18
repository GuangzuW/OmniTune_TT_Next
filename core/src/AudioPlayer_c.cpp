#include "AudioPlayer_c.h"
#include "AudioPlayer.h"
#include "FileScanner.h"
#include "LyricsParser.h"
#include <vector>
#include <string>

// --- AudioPlayer ---
AudioPlayerPtr AudioPlayer_create() { return new AudioPlayer(); }
void AudioPlayer_destroy(AudioPlayerPtr player) { delete static_cast<AudioPlayer*>(player); }
bool AudioPlayer_load(AudioPlayerPtr player, const char* filePath) { return static_cast<AudioPlayer*>(player)->load(filePath); }
void AudioPlayer_play(AudioPlayerPtr player) { static_cast<AudioPlayer*>(player)->play(); }
void AudioPlayer_pause(AudioPlayerPtr player) { static_cast<AudioPlayer*>(player)->pause(); }
void AudioPlayer_stop(AudioPlayerPtr player) { static_cast<AudioPlayer*>(player)->stop(); }
void AudioPlayer_seekTo(AudioPlayerPtr player, float position) { static_cast<AudioPlayer*>(player)->seekTo(position); }
float AudioPlayer_getPosition(AudioPlayerPtr player) { return static_cast<AudioPlayer*>(player)->getPosition(); }
float AudioPlayer_getDuration(AudioPlayerPtr player) { return static_cast<AudioPlayer*>(player)->getDuration(); }
bool AudioPlayer_isPlaying(AudioPlayerPtr player) { return static_cast<AudioPlayer*>(player)->isPlaying(); }

// --- FileScanner ---
struct ScanResult { std::vector<AudioFileInfo> files; };
ScanResultPtr FileScanner_scan(const char* dirPath) {
    ScanResult* result = new ScanResult();
    result->files = FileScanner::scanDirectory(dirPath);
    return result;
}
int ScanResult_getCount(ScanResultPtr result) { return result ? static_cast<ScanResult*>(result)->files.size() : 0; }
const char* ScanResult_getPath(ScanResultPtr result, int index) {
    if (!result) return nullptr;
    auto& files = static_cast<ScanResult*>(result)->files;
    return (index >= 0 && index < static_cast<int>(files.size())) ? files[index].path.c_str() : nullptr;
}
const char* ScanResult_getFileName(ScanResultPtr result, int index) {
    if (!result) return nullptr;
    auto& files = static_cast<ScanResult*>(result)->files;
    return (index >= 0 && index < static_cast<int>(files.size())) ? files[index].fileName.c_str() : nullptr;
}
void ScanResult_destroy(ScanResultPtr result) { if (result) delete static_cast<ScanResult*>(result); }

// --- LyricsParser ---
struct LyricsResult { std::vector<LyricLine> lyrics; };
LyricsResultPtr LyricsParser_parse(const char* lrcContent) {
    LyricsResult* result = new LyricsResult();
    result->lyrics = LyricsParser::parse(lrcContent);
    return result;
}
int LyricsResult_getCount(LyricsResultPtr result) { return result ? static_cast<LyricsResult*>(result)->lyrics.size() : 0; }
float LyricsResult_getTimestamp(LyricsResultPtr result, int index) {
    if (!result) return 0.0f;
    auto& lyrics = static_cast<LyricsResult*>(result)->lyrics;
    return (index >= 0 && index < static_cast<int>(lyrics.size())) ? lyrics[index].timestamp : 0.0f;
}
const char* LyricsResult_getText(LyricsResultPtr result, int index) {
    if (!result) return nullptr;
    auto& lyrics = static_cast<LyricsResult*>(result)->lyrics;
    return (index >= 0 && index < static_cast<int>(lyrics.size())) ? lyrics[index].text.c_str() : nullptr;
}
void LyricsResult_destroy(LyricsResultPtr result) { if (result) delete static_cast<LyricsResult*>(result); }
