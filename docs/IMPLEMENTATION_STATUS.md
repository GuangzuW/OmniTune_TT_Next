# Implementation Status

The per-task checklists in `docs/tasks/` describe *intended* scope and were all
marked complete, but several features were UI-only stubs or never wired up. This
document tracks the **code-verified** state after the desktop-first + full-cloud
implementation pass.

## ✅ Working and verified

| Area | Status | Notes / verification |
|------|--------|----------------------|
| Local playback (play/pause/seek/position) | ✅ | miniaudio engine, `core/src/AudioPlayer.cpp` |
| 10-band Equalizer (audible) | ✅ Fixed | EQ now a chain of `ma_peak_node`s inserted between the sound and the engine endpoint (`core/src/Equalizer.cpp`). Previously the filters were never attached to the graph. Verified: core builds + `test_core` runs. |
| Metadata extraction (title/artist/album/duration) | ✅ New | `core/src/MetadataExtractor.cpp` parses ID3v2 (MP3) + Vorbis comments (FLAC) and reads duration via `ma_decoder`. Verified by parsing a synthetic ID3v2 file. |
| Playlist next/prev + auto-advance | ✅ Fixed | `app/lib/main.dart` (`_playTrackAt`/`_next`/`_prev`); wired to transport buttons, system tray, and OS media controls (`background_audio.dart`). Previously empty `() {}` handlers. |
| Real metadata in UI | ✅ Fixed | LCD + playlist rows show title/artist/duration from the scanner. |
| Redis caching (aggregator) | ✅ Fixed | `backend/aggregator/main.go` now uses the cache (was discarded with `_ =`). Verified: `X-Cache: MISS` then `HIT` on repeat search. |
| JWT auth (user-sync) | ✅ Fixed | `backend/user_sync/main.go` issues real HS256 JWTs with bcrypt-hashed passwords (was `"JWT_TOKEN_MOCK"`). Verified: register/login returns a 3-part token; bad creds → 401. |
| PostgreSQL playlist sync | ✅ Fixed | Schema auto-created; `/sync/playlist` upsert + `/playlists` fetch, auth-protected. Verified end-to-end incl. row in Postgres. |
| Audius streaming client + UI | ✅ New + Fixed | `app/lib/api_client.dart` + online search panel; remote tracks downloaded to temp and played. **Fixed the Audius host resolution** (`api.audius.co` is a discovery *selector*, not the API host) — verified live search now returns real tracks with artwork/duration. |
| Cloud login + sync UI | ✅ New | Login/register dialog, sync-to-cloud / load-from-cloud buttons. |
| Volume control | ✅ New | `ma_engine` master volume via `AudioPlayer_setVolume/getVolume` + UI slider. Verified exported in the DLL. |
| UI redesign | ✅ New | Polished retro-LCD skin: now-playing card w/ artwork, dual time labels, shuffle + repeat (off/all/one), volume, EQ presets (Rock/Pop/Jazz/Bass/Vocal/Flat), folder picker, panel toggles, status bar, graceful "core not loaded" handling. |
| Docker backend | ✅ Fixed | Fixed a build bug: `go build -o aggregator`/`-o user_sync` collided with the same-named source dirs, so the binary was misplaced and containers crash-looped on start. Now builds to `/out` and runs. |
| Mobile native wiring | ✅ Ready | FFI loader handles iOS (`DynamicLibrary.process()`) + Android (`libTTPlayerCore.so`); core CMake has an `ANDROID` branch; `core/TTPlayerCore.podspec` for iOS; `docs/MOBILE_SETUP.md` has exact Gradle/Podfile steps. Build it on macOS after `scripts/setup_platforms.sh`. |

## 🔧 Hardening (ready-to-run fixes)

- **Tray icons**: added `app/assets/app_icon.png` + `.ico` and declared them in
  `pubspec.yaml` (the tray loaded missing assets before and silently failed).
- **macOS entitlements**: added `network.client`, `files.user-selected.read-only`,
  `assets.music.read-only`, and `disable-library-validation` to Debug+Release —
  without these the sandbox blocked HTTP (backend/Audius), reading music files,
  and loading the FFI dylib.
- **widget_test.dart**: replaced the stale counter-template test (referenced the
  deleted `MyApp`, which broke `flutter test`) with real smoke tests.
- **FFI loader**: also searches the macOS `.app` `Contents/Frameworks`.

## ⚠️ Requires a one-time step on a machine with the Flutter SDK

| Item | What's needed |
|------|---------------|
| Platform runners | Only `app/macos/` and `app/web/` are checked in. Run `scripts/setup_platforms.sh` (wraps `flutter create --platforms=windows,macos,linux,ios,android .`). |
| Native core per platform | Desktop: `scripts/build_desktop.{sh,ps1}`. Mobile: follow `docs/MOBILE_SETUP.md` (one Gradle block for Android, one Podfile line for iOS). All the supporting files (CMake branches, podspec, FFI loader) are already in place. |

## ⛔ Deferred (out of current scope)

- **Web audio** — Dart FFI cannot run on web. The `core/build_wasm/` output
  exists but is not bridged to the Flutter web app (would need a JS-interop
  shim around the Emscripten module).
- **Embedded album-art extraction** — folder-convention art works; pulling
  APIC/PICTURE blocks out of tags is not yet implemented (the parser reads text
  frames only). Online (Audius) tracks do show artwork.
- **Embedded album art extraction** — folder-convention art (cover.jpg/folder.jpg)
  works; pulling APIC/PICTURE blocks out of tags is not yet implemented (the
  parser locates text frames only).
