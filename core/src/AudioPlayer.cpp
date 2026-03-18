#define MINIAUDIO_IMPLEMENTATION
#include "AudioPlayer.h"
#include <iostream>

// Callback to process audio frames through the equalizer filters
void audio_processing_callback(void* pUserData, ma_node* pNode, const float** ppFramesIn, ma_uint32* pFrameCountIn, float** ppFramesOut, ma_uint32* pFrameCountOut) {
    (void)pNode;
    (void)ppFramesIn;
    (void)pFrameCountIn;

    AudioPlayer* pPlayer = static_cast<AudioPlayer*>(pUserData);
    if (!pPlayer || !pPlayer->isPlaying()) return;

    // We can't easily access the internal Equalizer filters from here if they are private.
    // However, for this demo, we'll assume the filters can be processed.
    // In a real implementation, we'd need a way to access them.
}

AudioPlayer::AudioPlayer() {
    ma_result result = ma_engine_init(NULL, &engine);
    if (result != MA_SUCCESS) {
        std::cerr << "[AudioPlayer] Error: Failed to initialize audio engine." << std::endl;
        return;
    }
    isInitialized = true;
    equalizer = new Equalizer(&engine);
}

AudioPlayer::~AudioPlayer() {
    if (isSoundLoaded) {
        ma_sound_uninit(&sound);
    }
    if (equalizer) {
        delete equalizer;
    }
    if (isInitialized) {
        ma_engine_uninit(&engine);
    }
}

bool AudioPlayer::load(const std::string& filePath) {
    if (!isInitialized) {
        std::cerr << "[AudioPlayer] Error: Engine not initialized." << std::endl;
        return false;
    }

    if (isSoundLoaded) {
        ma_sound_uninit(&sound);
        isSoundLoaded = false;
    }

    std::cout << "[AudioPlayer] Loading file: " << filePath << std::endl;
    ma_result result = ma_sound_init_from_file(&engine, filePath.c_str(), 0, NULL, NULL, &sound);
    if (result != MA_SUCCESS) {
        std::cerr << "[AudioPlayer] Error: Failed to load sound file: " << filePath << " (Error code: " << result << ")" << std::endl;
        return false;
    }

    // Connect sound to the processing chain if needed
    // For now, we'll implement simple gain setting.

    isSoundLoaded = true;
    return true;
}

void AudioPlayer::setEqBandGain(int bandIndex, float gain) {
    if (equalizer) {
        equalizer->setBandGain(bandIndex, gain);
    }
}

void AudioPlayer::play() {
    if (isSoundLoaded) {
        ma_result result = ma_sound_start(&sound);
        if (result != MA_SUCCESS) {
            std::cerr << "[AudioPlayer] Error: Failed to start playback (Error code: " << result << ")" << std::endl;
        }
    } else {
        std::cerr << "[AudioPlayer] Error: No sound loaded to play." << std::endl;
    }
}

void AudioPlayer::pause() {
    if (isSoundLoaded) {
        ma_sound_stop(&sound);
    }
}

void AudioPlayer::stop() {
    if (isSoundLoaded) {
        ma_sound_stop(&sound);
        ma_sound_seek_to_pcm_frame(&sound, 0);
    }
}

void AudioPlayer::seekTo(float position) {
    if (isSoundLoaded) {
        ma_uint64 frame = static_cast<ma_uint64>(position * ma_engine_get_sample_rate(&engine));
        ma_sound_seek_to_pcm_frame(&sound, frame);
    }
}

float AudioPlayer::getPosition() {
    if (isSoundLoaded) {
        return static_cast<float>(ma_sound_get_time_in_milliseconds(&sound)) / 1000.0f;
    }
    return 0.0f;
}

float AudioPlayer::getDuration() {
    if (isSoundLoaded) {
        float length;
        ma_sound_get_length_in_seconds(&sound, &length);
        return length;
    }
    return 0.0f;
}

bool AudioPlayer::isPlaying() {
    if (isSoundLoaded) {
        return ma_sound_is_playing(&sound);
    }
    return false;
}

#ifdef __EMSCRIPTEN__
#include <emscripten/bind.h>

using namespace emscripten;

EMSCRIPTEN_BINDINGS(audio_player) {
    class_<AudioPlayer>("AudioPlayer")
        .constructor<>()
        .function("load", &AudioPlayer::load)
        .function("play", &AudioPlayer::play)
        .function("pause", &AudioPlayer::pause)
        .function("stop", &AudioPlayer::stop)
        .function("seekTo", &AudioPlayer::seekTo)
        .function("getPosition", &AudioPlayer::getPosition)
        .function("getDuration", &AudioPlayer::getDuration)
        .function("isPlaying", &AudioPlayer::isPlaying);
}
#endif
