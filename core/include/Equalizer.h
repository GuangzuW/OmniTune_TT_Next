#pragma once

#include "miniaudio.h"
#include <vector>

class Equalizer {
public:
    Equalizer(ma_engine* engine);
    ~Equalizer();

    void setBandGain(int bandIndex, float gain); // gain in dB (-12 to +12)
    float getBandGain(int bandIndex) const;

    static const int BAND_COUNT = 10;
    static const float BAND_FREQUENCIES[BAND_COUNT];

private:
    ma_engine* engine;
    ma_peak2 filters[BAND_COUNT];
    float gains[BAND_COUNT];
    bool initialized[BAND_COUNT];
};
