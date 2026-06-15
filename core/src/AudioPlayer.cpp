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

    // Route the sound through the equalizer chain instead of straight to the
    // endpoint, so per-band gains actually affect the rendered audio. If the
    // equalizer has no initialized bands, leave the default endpoint routing.
    if (equalizer != nullptr) {
        ma_node* eqInput = equalizer->getInputNode();
        if (eqInput != NULL) {
            ma_node_attach_output_bus(&sound, 0, eqInput, 0);
        }
    }

    isSoundLoaded = true;
    return true;
}

void AudioPlayer::setEqBandGain(int bandIndex, float gain) {
    if (equalizer) {
        equalizer->setBandGain(bandIndex, gain);
    }
}

void AudioPlayer::setVolume(float volume) {
    if (isInitialized) {
        if (volume < 0.0f) volume = 0.0f;
        ma_engine_set_volume(&engine, volume);
    }
}

float AudioPlayer::getVolume() {
    if (isInitialized) {
        return ma_engine_get_volume(&engine);
    }
    return 1.0f;
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
        .function("isPlaying", &AudioPlayer::isPlaying)
        .function("setEqBandGain", &AudioPlayer::setEqBandGain)
        .function("setVolume", &AudioPlayer::setVolume)
        .function("getVolume", &AudioPlayer::getVolume);
}
#endif
