#!/bin/bash
# Builds the OmniTune desktop app on macOS/Linux: compiles the C++ core,
# builds the Flutter app, and bundles the native library next to the runner.
#
# Prerequisites: CMake + a C++17 compiler, and the Flutter SDK on PATH.
# One-time setup (generates the runner):  cd app && flutter create --platforms=macos .
#
# Usage: scripts/build_desktop.sh [macos|linux]

set -e
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT="$( dirname "$SCRIPT_DIR" )"
TARGET="${1:-macos}"

echo "==> Building C++ core..."
cmake -S "$ROOT/core" -B "$ROOT/core/build"
cmake --build "$ROOT/core/build"

if [ "$TARGET" = "macos" ]; then
    LIB="$ROOT/core/build/libTTPlayerCore.dylib"
else
    LIB="$ROOT/core/build/libTTPlayerCore.so"
fi
[ -f "$LIB" ] || { echo "Core library not found at $LIB"; exit 1; }
echo "    Core library: $LIB"

if [ ! -d "$ROOT/app/$TARGET" ]; then
    echo "WARNING: app/$TARGET runner not found."
    echo "Run:  cd app && flutter create --platforms=$TARGET ."
    exit 1
fi

echo "==> Building Flutter $TARGET app..."
cd "$ROOT/app"
flutter build "$TARGET" --release

# Bundle the library into the .app so it loads without a loose path.
if [ "$TARGET" = "macos" ]; then
    APP=$(find "$ROOT/app/build/macos" -maxdepth 4 -name "*.app" -type d | head -n1)
    if [ -n "$APP" ]; then
        mkdir -p "$APP/Contents/Frameworks"
        cp "$LIB" "$APP/Contents/Frameworks/"
        echo "==> Bundled dylib into $APP/Contents/Frameworks"
    fi
fi
echo "Done."
