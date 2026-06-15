#!/bin/bash

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( dirname "$SCRIPT_DIR" )"

# Source the local emsdk environment if present. In the emscripten/emsdk Docker
# image emcc is already on PATH, so skip sourcing there.
if [ -f "$PROJECT_ROOT/emsdk/emsdk_env.sh" ]; then
    source "$PROJECT_ROOT/emsdk/emsdk_env.sh"
fi

# Create build directory
mkdir -p "$PROJECT_ROOT/core/build_wasm"
cd "$PROJECT_ROOT/core/build_wasm"

# Compile with emcc
# -s WASM=1: Generate WebAssembly
# -s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]': Export runtime methods
# -s MODULARIZE=1: Wrap the generated JS in a module
# -s EXPORT_NAME='TTPlayerCore': Name of the module
# --bind: Use Embind
# -O3: Optimize
# -s USE_PTHREADS=1: Enable pthreads (miniaudio needs it for some backends, though Wasm audio usually uses AudioWorklets)
# -s AUDIO_WORKLET=1: Enable AudioWorklet support (experimental but better for performance)
# -s FORCE_FILESYSTEM=1: If needed for loading files

# AudioPlayer.cpp defines MINIAUDIO_IMPLEMENTATION and now depends on the
# Equalizer (node graph). LyricsParser is bundled too so the web app can parse
# .lrc client-side. miniaudio uses its Web Audio backend under emscripten.
emcc ../src/AudioPlayer.cpp \
    ../src/Equalizer.cpp \
    ../src/LyricsParser.cpp \
    -I../include \
    -o TTPlayerCore.js \
    -s WASM=1 \
    -s MODULARIZE=1 \
    -s EXPORT_NAME='TTPlayerCore' \
    -s FORCE_FILESYSTEM=1 \
    -s EXPORTED_RUNTIME_METHODS='["FS", "ccall", "cwrap"]' \
    -s ENVIRONMENT='web,worker' \
    --bind \
    -O3 \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s ASSERTIONS=1 \
    -std=c++17
    # NOTE: do NOT pass -DMINIAUDIO_IMPLEMENTATION globally — AudioPlayer.cpp
    # defines it internally. Defining it for every TU duplicates miniaudio's
    # implementation and the wasm linker fails on duplicate symbols.

echo "Wasm build complete: core/build_wasm/TTPlayerCore.js"
