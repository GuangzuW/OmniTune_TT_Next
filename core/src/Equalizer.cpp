#include "Equalizer.h"
#include <iostream>

const float Equalizer::BAND_FREQUENCIES[Equalizer::BAND_COUNT] = {
    31.0f, 62.0f, 125.0f, 250.0f, 500.0f, 1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f
};

Equalizer::Equalizer(ma_engine* engine) : engine(engine), firstBand(-1) {
    ma_node_graph* graph = ma_engine_get_node_graph(engine);
    ma_uint32 channels = ma_engine_get_channels(engine);
    ma_uint32 sampleRate = ma_engine_get_sample_rate(engine);

    for (int i = 0; i < BAND_COUNT; i++) {
        gains[i] = 0.0f;
        initialized[i] = false;

        ma_peak_node_config config = ma_peak_node_config_init(
            channels,
            sampleRate,
            0.0,                    // gainDB (flat by default)
            1.0,                    // Q
            BAND_FREQUENCIES[i]
        );

        ma_result result = ma_peak_node_init(graph, &config, NULL, &filters[i]);
        if (result != MA_SUCCESS) {
            std::cerr << "[Equalizer] Error: Failed to initialize filter node for band "
                      << i << " (Error code: " << result << ")" << std::endl;
            continue;
        }
        initialized[i] = true;
    }

    // Wire the initialized bands into a chain and attach the tail to the engine
    // endpoint: firstBand -> ... -> lastBand -> endpoint.
    ma_node* endpoint = ma_node_graph_get_endpoint(graph);
    ma_node* prev = NULL;
    for (int i = 0; i < BAND_COUNT; i++) {
        if (!initialized[i]) continue;
        if (firstBand < 0) firstBand = i;
        if (prev != NULL) {
            ma_node_attach_output_bus(prev, 0, &filters[i], 0);
        }
        prev = (ma_node*)&filters[i];
    }
    if (prev != NULL) {
        ma_node_attach_output_bus(prev, 0, endpoint, 0);
    }
}

Equalizer::~Equalizer() {
    for (int i = 0; i < BAND_COUNT; i++) {
        if (initialized[i]) {
            ma_peak_node_uninit(&filters[i], NULL);
        }
    }
}

void Equalizer::setBandGain(int bandIndex, float gain) {
    if (bandIndex < 0 || bandIndex >= BAND_COUNT) return;

    gains[bandIndex] = gain;
    if (!initialized[bandIndex]) return;

    // Reinit only the biquad coefficients of the live node (no graph surgery),
    // which updates the gain without dropping the audio stream.
    ma_peak_node_config config = ma_peak_node_config_init(
        ma_engine_get_channels(engine),
        ma_engine_get_sample_rate(engine),
        (double)gain,
        1.0,
        BAND_FREQUENCIES[bandIndex]
    );
    ma_peak_node_reinit(&config.peak, &filters[bandIndex]);
}

float Equalizer::getBandGain(int bandIndex) const {
    if (bandIndex < 0 || bandIndex >= BAND_COUNT) return 0.0f;
    return gains[bandIndex];
}

ma_node* Equalizer::getInputNode() const {
    if (firstBand < 0) return NULL;
    return (ma_node*)&filters[firstBand];
}
