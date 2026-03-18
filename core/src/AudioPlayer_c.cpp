#include "AudioPlayer_c.h"
#include "AudioPlayer.h"
#include "FileScanner.h"
#include <vector>
#include <string>

// --- AudioPlayer ---

AudioPlayerPtr AudioPlayer_create() {
    return new AudioPlayer();
}

void AudioPlayer_destroy(AudioPlayerPtr player) {
    delete static_cast<AudioPlayer*>(player);
}

bool AudioPlayer_load(AudioPlayerPtr player, const char* filePath) {
    return static_cast<AudioPlayer*>(player)->load(filePath);
}

void AudioPlayer_play(AudioPlayerPtr player) {
    static_cast<AudioPlayer*>(player)->play();
}

void AudioPlayer_pause(AudioPlayerPtr player) {
    static_cast<AudioPlayer*>(player)->pause();
}

void AudioPlayer_stop(AudioPlayerPtr player) {
    static_cast<AudioPlayer*>(player)->stop();
}

void AudioPlayer_seekTo(AudioPlayerPtr player, float position) {
    static_cast<AudioPlayer*>(player)->seekTo(position);
}

float AudioPlayer_getPosition(AudioPlayerPtr player) {
    return static_cast<AudioPlayer*>(player)->getPosition();
}

float AudioPlayer_getDuration(AudioPlayerPtr player) {
    return static_cast<AudioPlayer*>(player)->getDuration();
}

bool AudioPlayer_isPlaying(AudioPlayerPtr player) {
    return static_cast<AudioPlayer*>(player)->isPlaying();
}

// --- FileScanner ---

struct ScanResult {
    std::vector<AudioFileInfo> files;
};

ScanResultPtr FileScanner_scan(const char* dirPath) {
    ScanResult* result = new ScanResult();
    result->files = FileScanner::scanDirectory(dirPath);
    return result;
}

int ScanResult_getCount(ScanResultPtr result) {
    if (!result) return 0;
    return static_cast<ScanResult*>(result)->files.size();
}

const char* ScanResult_getPath(ScanResultPtr result, int index) {
    if (!result) return nullptr;
    auto& files = static_cast<ScanResult*>(result)->files;
    if (index < 0 || index >= static_cast<int>(files.size())) return nullptr;
    return files[index].path.c_str();
}

const char* ScanResult_getFileName(ScanResultPtr result, int index) {
    if (!result) return nullptr;
    auto& files = static_cast<ScanResult*>(result)->files;
    if (index < 0 || index >= static_cast<int>(files.size())) return nullptr;
    return files[index].fileName.c_str();
}

void ScanResult_destroy(ScanResultPtr result) {
    if (result) {
        delete static_cast<ScanResult*>(result);
    }
}
