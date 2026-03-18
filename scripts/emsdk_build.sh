#!/bin/bash

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( dirname "$SCRIPT_DIR" )"

# Source emsdk environment
source "$PROJECT_ROOT/emsdk/emsdk_env.sh"

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

emcc ../src/AudioPlayer.cpp \
    -I../include \
    -o TTPlayerCore.js \
    -s WASM=1 \
    -s MODULARIZE=1 \
    -s EXPORT_NAME='TTPlayerCore' \
    -s FORCE_FILESYSTEM=1 \
    -s EXPORTED_RUNTIME_METHODS='["FS", "ccall", "cwrap"]' \
    --bind \
    -O3 \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s ASSERTIONS=1 \
    -std=c++17 \
    -DMINIAUDIO_IMPLEMENTATION

echo "Wasm build complete: core/build_wasm/TTPlayerCore.js"
