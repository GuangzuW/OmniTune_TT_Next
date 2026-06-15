#!/bin/bash
# Generates the Flutter platform runners that aren't checked in (the repo ships
# only macos/ and web/). Run this once on a machine with the Flutter SDK, then
# follow docs/MOBILE_SETUP.md to wire the native core into iOS/Android.
#
# Usage: scripts/setup_platforms.sh [platforms]
#   default: windows,macos,linux,ios,android
set -e
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT="$( dirname "$SCRIPT_DIR" )"
PLATFORMS="${1:-windows,macos,linux,ios,android}"

cd "$ROOT/app"
echo "==> Generating runners for: $PLATFORMS"
flutter create --platforms="$PLATFORMS" .
flutter pub get

echo ""
echo "Done. Next steps:"
echo "  Desktop:  ../scripts/build_desktop.sh macos   (or build_desktop.ps1 on Windows)"
echo "  Mobile:   see docs/MOBILE_SETUP.md to wire the C++ core into iOS/Android"
