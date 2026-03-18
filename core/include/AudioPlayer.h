#ifndef AUDIO_PLAYER_H
#define AUDIO_PLAYER_H

#include <string>
#include "miniaudio.h"

class AudioPlayer {
public:
    AudioPlayer();
    ~AudioPlayer();

    bool load(const std::string& filePath);
    void play();
    void pause();
    void stop();
    void seekTo(float position); // position in seconds
    float getPosition();
    float getDuration();
    bool isPlaying();

private:
    ma_engine engine;
    ma_sound sound;
    bool isInitialized = false;
    bool isSoundLoaded = false;
};

#endif // AUDIO_PLAYER_H
