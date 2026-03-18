#ifndef AUDIO_PLAYER_H
#define AUDIO_PLAYER_H

#include <string>
#include "miniaudio.h"
#include "Equalizer.h"

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

    void setEqBandGain(int bandIndex, float gain);

private:
    ma_engine engine;
    ma_sound sound;
    bool isInitialized = false;
    bool isSoundLoaded = false;
    Equalizer* equalizer = nullptr;

    // Optional: for manual processing if needed, but miniaudio often manages nodes.
};

#endif // AUDIO_PLAYER_H
