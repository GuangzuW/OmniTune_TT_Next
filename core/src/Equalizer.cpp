#include "Equalizer.h"
#include <iostream>

const float Equalizer::BAND_FREQUENCIES[Equalizer::BAND_COUNT] = {
    31.0f, 62.0f, 125.0f, 250.0f, 500.0f, 1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f
};

Equalizer::Equalizer(ma_engine* engine) : engine(engine) {
    for (int i = 0; i < BAND_COUNT; i++) {
        gains[i] = 0.0f;
        initialized[i] = false;

        ma_peak2_config config = ma_peak2_config_init(
            ma_format_f32,
            ma_engine_get_channels(engine),
            ma_engine_get_sample_rate(engine),
            0.0, // gainDB
            1.0, // Q
            BAND_FREQUENCIES[i]
        );

        ma_result result = ma_peak2_init(&config, NULL, &filters[i]);
        if (result == MA_SUCCESS) {
            initialized[i] = true;
        } else {
            std::cerr << "[Equalizer] Error: Failed to initialize filter for band " << i << std::endl;
        }
    }
}

Equalizer::~Equalizer() {
    for (int i = 0; i < BAND_COUNT; i++) {
        if (initialized[i]) {
            ma_peak2_uninit(&filters[i], NULL);
        }
    }
}

void Equalizer::setBandGain(int bandIndex, float gain) {
    if (bandIndex < 0 || bandIndex >= BAND_COUNT) return;
    
    gains[bandIndex] = gain;
    if (initialized[bandIndex]) {
        ma_peak2_config config = ma_peak2_config_init(
            ma_format_f32,
            ma_engine_get_channels(engine),
            ma_engine_get_sample_rate(engine),
            (double)gain,
            1.0,
            BAND_FREQUENCIES[bandIndex]
        );
        ma_peak2_init(&config, NULL, &filters[bandIndex]);
    }
}

float Equalizer::getBandGain(int bandIndex) const {
    if (bandIndex < 0 || bandIndex >= BAND_COUNT) return 0.0f;
    return gains[bandIndex];
}
