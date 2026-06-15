# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

OmniTune TT Next is a cross-platform audio player (inspired by TTPlayer / 千千静听) built from three independent layers that live in one repo:

- **`core/`** — C++17 audio engine compiled to a native shared library (desktop, via FFI) **and** to WebAssembly (web).
- **`app/`** — Flutter desktop/web/mobile UI that drives the core over Dart FFI.
- **`backend/`** — two Go microservices (music aggregation + user sync) deployed via Docker/K8s.

These layers do not share a build system — each is built and tested with its own toolchain.

## Build & Run

### Core (C++ native library)
```bash
mkdir -p core/build && cd core/build
cmake ..
make                 # produces libTTPlayerCore.{dylib,so} / TTPlayerCore.dll + test_core
./test_core          # the only C++ test target (basic AudioPlayer lifecycle check)
```
On Windows use the MSVC/Ninja generator (`cmake -G "Visual Studio 17 2022" ..` then build). Platform audio backends are linked conditionally in `core/CMakeLists.txt` (winmm / CoreAudio+AudioToolbox / ALSA).

### Core (WebAssembly)
```bash
./scripts/emsdk_build.sh   # requires an emsdk/ checkout at repo root (sourced by the script)
```
Note: the Wasm build compiles **only** `AudioPlayer.cpp` with `-DMINIAUDIO_IMPLEMENTATION`; the scanner/lyrics/EQ modules are native-only.

### Flutter app
```bash
cd app
flutter pub get
flutter run -d macos   # or -d windows / -d linux / -d chrome
flutter analyze        # lint (rules in app/analysis_options.yaml -> flutter_lints)
flutter test           # widget/unit tests in app/test/
flutter test test/widget_test.dart   # single test file
```

### Backend (Go services)
```bash
cd backend
go build ./...
go run aggregator/main.go    # serves :8000 (Audius search + stream proxy)
go run user_sync/main.go     # serves :8001 (auth + playlist sync)
go test ./...
docker-compose up -d         # from repo root: aggregator, user-sync, redis, postgres
```

## Architecture & Cross-Layer Contracts

### The FFI boundary is the spine of the app
The C++ core exposes a **C ABI** in `core/include/AudioPlayer_c.h` (implemented in `AudioPlayer_c.cpp`) — this is the *only* surface Flutter talks to. The C++ classes (`AudioPlayer`, `FileScanner`, `LyricsParser`, `Equalizer`) are never called directly across the boundary; they are wrapped by `extern "C"` functions that pass opaque `void*` handles.

`app/lib/audio_player_ffi.dart` mirrors this header exactly: every C function has a matching `typedef ...Native` / `typedef ...` pair and a `lookupFunction` call. **If you add or change a C++ exported function, you must update three places in lockstep:** `AudioPlayer_c.h`, `AudioPlayer_c.cpp`, and `audio_player_ffi.dart`. Symbol-name mismatches fail only at runtime (`lookupFunction` throws).

Memory ownership across the boundary: scan/lyrics calls return an opaque result handle that the Dart side must release via the matching `*_destroy` function after copying strings out (see `scanDirectory` / `parseLyrics` in the FFI file).

### Native library loading is CWD-relative (gotcha)
`AudioPlayerFFI._loadLibrary()` looks for the dylib at `<Directory.current.path>/core/build/libTTPlayerCore.dylib`, then falls back to the bare library name on the system search path. The path is resolved relative to the **process working directory at launch**, not the app bundle. Building the core into `core/build/` and launching with the repo root as CWD is the happy path; running from elsewhere relies on the library being installed on the loader path.

### Flutter app structure
`app/lib/` is flat and small — each file is a service the `_PlayerHomePageState` in `main.dart` composes:
- `audio_player_ffi.dart` — the FFI bridge (above).
- `metadata_cache.dart` — local SQLite cache (sqflite) for scanned-library metadata.
- `background_audio.dart` — `audio_service` handler for OS media controls / lock screen.
- `tray_service.dart` — system tray (`tray_manager`).
Desktop integration (frameless window via `window_manager`, global hotkeys via `hotkey_manager`, drag-and-drop via `desktop_drop`) is wired in `main()` and guarded by `!kIsWeb && Platform.is{MacOS,Windows,Linux}` so the same codebase still builds for web/mobile.

### Backend services are independent and stateless-ish
The two Go services share one module (`omnitune/backend`) but are separate `main` packages with separate Dockerfiles (`Dockerfile` → aggregator, `Dockerfile.user_sync` → user-sync). They do not call each other.
- **aggregator** (`backend/aggregator/`): proxies the Audius API (`audius/client.go`), with a Redis cache layer scaffolded in `cache/redis.go`. Config via `REDIS_ADDR` / `PORT` env vars.
- **user_sync** (`backend/user_sync/`): Postgres-backed auth + playlist sync. Config via `DATABASE_URL` / `PORT` / `JWT_SECRET`. Implements real HS256 JWT auth (bcrypt password hashing) and playlist upsert/fetch; schema is auto-created on startup. Protected routes require `Authorization: Bearer <token>`.

**Docker gotcha (fixed, don't reintroduce):** the build must output binaries to a path that doesn't collide with the same-named source directories — use `go build -o /out/aggregator ./aggregator` (NOT `-o aggregator aggregator/main.go`, which writes the binary *inside* the `aggregator/` dir and makes the container's `CMD ["./aggregator"]` fail).

## Conventions

- **C++**: modern C++17; errors are logged to `std::cerr`. `AudioPlayer` owns the miniaudio `ma_engine`/`ma_sound` lifecycle (RAII).
- **Equalizer**: 10 bands (31Hz–16kHz); set per-band gain through `AudioPlayer_setEqBandGain(player, bandIndex, gain)`. The bands are `ma_peak_node`s chained between each loaded sound and the engine endpoint (`Equalizer::getInputNode()` is attached in `AudioPlayer::load`), so gain changes are audible.
- **Metadata**: `MetadataExtractor` (`core/src/MetadataExtractor.cpp`) reads ID3v2/Vorbis tags + duration; `FileScanner` populates title/artist/album/duration, surfaced over the `ScanResult_get*` C ABI.
- **Windows DLL exports**: the core sets `WINDOWS_EXPORT_ALL_SYMBOLS` so the `extern "C"` ABI is visible in the DLL export table — required for the Dart FFI `lookupFunction` calls (and for `test_core` to link).
- **Native lib loading**: `audio_player_ffi.dart::_loadLibrary` searches the executable dir, then common CMake output dirs (incl. MSVC `Release/`), then the bare name — so bundled release builds and dev runs both resolve the library.
- **Commits**: Conventional Commits scoped by layer, e.g. `feat(core):`, `fix(app):`. Repo history tags work against the task docs in `docs/tasks/` (e.g. "Task 2.2").
- **Task docs**: `docs/tasks/task-*.md` track the phased roadmap; consult them for the intended scope of a feature before extending it.
