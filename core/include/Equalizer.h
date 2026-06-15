#pragma once

#include "miniaudio.h"

// 10-band peaking equalizer implemented as a chain of miniaudio node-graph
// filter nodes. The chain is inserted between a sound and the engine endpoint:
//
//     sound -> band[0] -> band[1] -> ... -> band[9] -> endpoint
//
// A loaded sound's output bus is attached to getInputNode(); the tail of the
// chain is attached to the engine endpoint by the constructor. This is what
// makes gain changes actually affect the audio that is rendered.
class Equalizer {
public:
    explicit Equalizer(ma_engine* engine);
    ~Equalizer();

    void setBandGain(int bandIndex, float gain); // gain in dB (-12 to +12)
    float getBandGain(int bandIndex) const;

    // First node of the chain — a sound should attach its output here so its
    // audio flows through the equalizer. Returns nullptr if no band initialized
    // (in which case the caller should attach directly to the endpoint).
    ma_node* getInputNode() const;

    static const int BAND_COUNT = 10;
    static const float BAND_FREQUENCIES[BAND_COUNT];

private:
    ma_engine* engine;
    ma_peak_node filters[BAND_COUNT];
    float gains[BAND_COUNT];
    bool initialized[BAND_COUNT];
    int firstBand; // index of the first successfully initialized band, or -1
};
