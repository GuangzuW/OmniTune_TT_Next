#define MINIAUDIO_IMPLEMENTATION
#include "AudioPlayer.h"
#include <iostream>

AudioPlayer::AudioPlayer() {
    ma_result result = ma_engine_init(NULL, &engine);
    if (result != MA_SUCCESS) {
        std::cerr << "[AudioPlayer] Error: Failed to initialize audio engine." << std::endl;
        return;
    }
    isInitialized = true;
}

AudioPlayer::~AudioPlayer() {
    if (isSoundLoaded) {
        ma_sound_uninit(&sound);
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

    isSoundLoaded = true;
    return true;
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
