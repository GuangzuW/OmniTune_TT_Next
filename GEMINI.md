# GEMINI.md - Music Player Project Context

## Project Overview
This project aims to replicate a high-performance, cross-platform music player inspired by the classic **TTPlayer (千千静听)**. It features a modern C++ core for audio processing, a Flutter-based UI for all platforms (Web, Mobile, Desktop), and a microservices-oriented backend in Go.

### Main Technologies
- **Core:** C++17, [miniaudio](https://github.com/mackron/miniaudio) for audio I/O, FFmpeg (planned) for decoding.
- **Frontend:** Flutter (Dart) using FFI to bridge with the C++ core.
- **Backend:** Go (Golang) for scalable microservices.
- **Infrastructure:** Docker, Kubernetes (planned).
- **Build System:** CMake (for C++), Flutter CLI, Go modules.

## Project Structure
- `core/`: High-performance C++ audio engine.
  - `include/`: Header files (e.g., `AudioPlayer.h`, `miniaudio.h`).
  - `src/`: Implementation files (e.g., `AudioPlayer.cpp`).
- `app/`: (TODO) Flutter application source code.
- `backend/`: (TODO) Go microservices for music aggregation and user sync.
- `scripts/`: Utility scripts for building, testing, and deployment.

## Building and Running
### Core Engine (C++)
To build the C++ shared library:
```bash
mkdir -p core/build
cd core/build
cmake ..
make
```

### Flutter App
- [ ] TODO: Document Flutter initialization and build commands.

### Backend Services
- [ ] TODO: Document Go service initialization and Docker commands.

## Development Conventions
- **C++ Coding Style:** Use modern C++17 features. Error handling should be explicit and logged to `std::cerr`.
- **Audio Engine:** `AudioPlayer` class manages the lifecycle of the `ma_engine` and `ma_sound` from the miniaudio library.
- **Cross-Platform:** The C++ core is designed to compile on Windows, macOS, Linux, and Web (via Emscripten).
- **Git Workflow:** Use descriptive commit messages (e.g., `feat(core): ...`, `fix(app): ...`).

## Key Files
- `core/CMakeLists.txt`: Build configuration for the core engine.
- `core/include/AudioPlayer.h`: Public interface for the audio engine.
- `core/src/AudioPlayer.cpp`: Core playback and audio management logic.
