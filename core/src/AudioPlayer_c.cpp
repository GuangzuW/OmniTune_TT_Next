#include "AudioPlayer_c.h"
#include "AudioPlayer.h"

extern "C" {

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

}
