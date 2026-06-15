# OmniTune TT Next — Planning & Task Log

A durable backup of the planning sessions and every task executed, grouped by
phase. Each task lists **what**, the **files touched**, how it was **verified**,
and its **status**. (Originally tracked in-session; persisted here so it survives.)

## How this project evolved

The repo's `docs/tasks/task-*.md` marked all 16 original tasks across 4 phases as
complete, but an audit found the code was ~**60%** real: local playback worked,
but the EQ, metadata, navigation, streaming, auth and several runners were stubs,
mocks, or missing. Three work phases followed:

- **Phase 1 — Desktop-first + full cloud + fix all gaps** (tasks 1–11)
- **Phase 2 — Polish, performance, cross-platform wiring** (tasks 12–16)
- **Phase 3 — Cloud-native web platform** (tasks 17–22)
- **Hardening pass** — ready-to-run fixes found during verification

### Scope decisions (confirmed by the user)
- Phase 1: **Desktop first (Windows + macOS)**; full cloud stack (Audius + Redis
  + real JWT auth + Postgres sync); **fix all** local-playback gaps.
- Phase 3: **Next.js** web frontend; **full cloud-native** platform; **WebAssembly**
  C++ core in the browser; **local K8s (kind/minikube)** target.

### Verification constraint
Work was authored on a Windows box. Verifiable there: C++ (MSVC), Go (Docker),
Node/Next build, WASM (emscripten Docker), Helm (Docker), full `docker compose`.
**Not** verifiable there (needs the user's Mac): in-browser WASM audio output,
Flutter macOS/iOS/Android runtime, a live kind cluster.

---

## Phase 1 — Desktop-first + full cloud + fix all gaps

### Task 1 — A1: Wire Equalizer into the miniaudio node graph ✅
Make the 10-band EQ actually affect audio. Rebuilt `Equalizer` as a chain of
`ma_peak_node`s inserted between each sound and the engine endpoint; removed the
dead `audio_processing_callback`; `setBandGain` now reinits the live node.
- Files: `core/include/Equalizer.h`, `core/src/Equalizer.cpp`, `core/src/AudioPlayer.cpp`
- Verify: core builds (MSVC), `test_core` runs; `WINDOWS_EXPORT_ALL_SYMBOLS` added so the C ABI is exported (also fixes Windows FFI + test link).

### Task 2 — A2: MetadataExtractor (ID3 / Vorbis + duration) ✅
New core module reading ID3v2 (MP3) and Vorbis comments (FLAC) tags, with
duration via `ma_decoder`; filename fallback. `FileScanner` populates
title/artist/album/duration.
- Files: `core/include/MetadataExtractor.h`, `core/src/MetadataExtractor.cpp`, `core/src/FileScanner.{h,cpp}`, `core/CMakeLists.txt`
- Verify: compiled a test against the DLL and parsed a synthetic ID3v2 file → title/artist/album extracted.

### Task 3 — A3: Extend C ABI + Dart FFI for metadata ✅
Added `ScanResult_getTitle/getArtist/getAlbum/getDuration` and matching Dart
bindings + `AudioFileInfo` fields (three-places-in-lockstep rule).
- Files: `core/include/AudioPlayer_c.h`, `core/src/AudioPlayer_c.cpp`, `app/lib/audio_player_ffi.dart`
- Verify: new symbols confirmed in the DLL export table.

### Task 4 — B1: Playlist navigation (next/prev) ✅
Added `_currentIndex`/`_playTrackAt`/`_next`/`_prev`; wired transport buttons,
tray callbacks, and `background_audio` `skipToNext/Previous`; auto-advance at end.
- Files: `app/lib/main.dart`, `app/lib/background_audio.dart`
- Verify: code review (Flutter not buildable on the dev box).

### Task 5 — B2: Display real metadata in UI ✅
Populated `MetadataCache` from extended scan results; removed hardcoded
"Unknown"; LCD + playlist rows show title/artist/duration.
- Files: `app/lib/main.dart`

### Task 6 — D1–D3: Windows runner + desktop lib bundling ✅
Added `WINDOWS_EXPORT_ALL_SYMBOLS`; robust `_loadLibrary` (searches exe dir +
CMake output dirs + macOS Frameworks); build scripts; documented the one-time
`flutter create --platforms=windows .` step (needs the SDK).
- Files: `core/CMakeLists.txt`, `app/lib/audio_player_ffi.dart`, `scripts/build_desktop.ps1`, `scripts/build_desktop.sh`, `README.md`

### Task 7 — C1: Activate Redis cache in the aggregator ✅
Stopped discarding the cache; `/search` does get-on-hit / set-on-miss with TTL,
graceful degradation; added `/health`.
- Files: `backend/aggregator/main.go`
- Verify: `X-Cache: MISS` then `HIT` on repeat search (Docker).

### Task 8 — B3: Audius streaming client + UI ✅
New `api_client.dart` (http) for search/stream; online search panel; remote
tracks downloaded to temp and played (the core plays from a path).
- Files: `app/lib/api_client.dart`, `app/lib/main.dart`, `app/pubspec.yaml`

### Task 9 — C2–C3: Real JWT auth + Postgres playlist sync ✅
Replaced the mocks: bcrypt + HS256 JWT (`/auth/register`, `/auth/login`), schema
auto-create (users/playlists/playlist_tracks), auth-protected
`/sync/playlist` + `/playlists`.
- Files: `backend/user_sync/main.go`, `backend/go.mod`
- Verify (Docker): 3-part JWT, 401 on bad creds/no token, playlist upsert + fetch, row confirmed in Postgres.

### Task 10 — B4: Cloud auth + sync UI in Flutter ✅
Login/register dialog, token persistence, sync-to-cloud / load-from-cloud.
- Files: `app/lib/main.dart`, `app/lib/api_client.dart`

### Task 11 — Docs reflect reality ✅
Created `docs/IMPLEMENTATION_STATUS.md`; corrected `README.md` (build steps, CWD
mismatch); updated `CLAUDE.md`.

**Also fixed a critical pre-existing Docker bug:** `go build -o aggregator`/`-o
user_sync` collided with the same-named source dirs, so the binary was misplaced
and containers crash-looped. Now builds to `/out`. (`backend/Dockerfile`, `backend/Dockerfile.user_sync`)

---

## Phase 2 — Polish, performance, cross-platform

### Task 12 — Volume control (core + FFI) ✅
`AudioPlayer_setVolume/getVolume` via `ma_engine`; Dart + (later) WASM bindings; UI slider.
- Files: `core/include/AudioPlayer.h`, `core/src/AudioPlayer.cpp`, `core/include/AudioPlayer_c.h`, `core/src/AudioPlayer_c.cpp`, `app/lib/audio_player_ffi.dart`
- Verify: symbols exported in the DLL.

### Task 13 — Fix Audius host resolution ✅
`api.audius.co` is a discovery *selector*, not the API host. Now resolves a
discovery host first (cached), then calls `/v1`. Enriched the track model with
duration + artwork.
- Files: `backend/aggregator/audius/client.go`
- Verify (Docker): live search returns real tracks with artwork/duration.

### Task 14 — UI redesign (polished retro skin) ✅
Rebuilt the Flutter widget layer: now-playing card w/ artwork, dual time labels,
shuffle + repeat (off/all/one), volume, EQ presets (Rock/Pop/Jazz/Bass/Vocal),
folder picker, panel toggles, status bar, graceful "core not loaded".
- Files: `app/lib/main.dart`, `app/pubspec.yaml` (added `file_picker`)

### Task 15 — Performance ✅
Throttled the poll timer (200 ms), non-blocking scan with spinner + status,
repeat/shuffle-aware auto-advance.
- Files: `app/lib/main.dart`

### Task 16 — Cross-platform native build wiring ✅
FFI loader handles iOS (`DynamicLibrary.process()`) + Android (`libTTPlayerCore.so`);
core CMake gained `ANDROID`/`iOS` branches; `core/TTPlayerCore.podspec`;
`scripts/setup_platforms.sh`; `docs/MOBILE_SETUP.md` (exact Gradle/Podfile steps).
- Files: `app/lib/audio_player_ffi.dart`, `core/CMakeLists.txt`, `core/TTPlayerCore.podspec`, `scripts/setup_platforms.sh`, `docs/MOBILE_SETUP.md`

---

## Phase 3 — Cloud-native web platform

### Task 17 — Extend + build the WASM C++ core ✅
Added Embind bindings for `setEqBandGain`/`setVolume`; fixed the WASM build to
compile `Equalizer.cpp`/`LyricsParser.cpp` and dropped the global
`-DMINIAUDIO_IMPLEMENTATION` (duplicate-symbol link error).
- Files: `core/src/AudioPlayer.cpp`, `scripts/emsdk_build.sh`
- Verify: `TTPlayerCore.wasm` (~0.45 MB) + `.js` built via the `emscripten/emsdk` Docker image.

### Task 18 — Next.js web app ✅
`web/` — Next.js 15 + React 19 + TypeScript + Tailwind. Player, Audius search,
WASM audio wrapper, cloud login/playlists. Standalone Dockerfile.
- Files: `web/**` (`app/page.tsx`, `lib/api.ts`, `lib/wasmPlayer.ts`, configs, `Dockerfile`), `web/public/wasm/*`
- Verify: `next build` passes (TypeScript clean); bumped to patched `next@15.5.19`.

### Task 19 — Observability: Prometheus metrics ✅
Shared metrics middleware (request count + latency histograms) + `/metrics` on
both Go services.
- Files: `backend/internal/metrics/metrics.go`, `backend/aggregator/main.go`, `backend/user_sync/main.go`
- Verify (Docker): `/metrics` exposes `http_requests_total` + Go runtime metrics.

### Task 20 — Full docker-compose stack ✅
web + aggregator + user-sync + redis + postgres + **NATS** + **MinIO** +
**Prometheus** + **Grafana** (provisioned datasource). Aggregator publishes
search events to NATS.
- Files: `docker-compose.yml`, `deploy/observability/prometheus.yml`, `deploy/observability/grafana/provisioning/datasources/datasource.yml`, `backend/aggregator/main.go`
- Verify: **9 services up**; web 200, Redis HIT, Prometheus 3 targets up, NATS `in_msgs:1`, Grafana healthy, MinIO running.

### Task 21 — Helm chart + K8s manifests ✅
`deploy/helm/omnitune` — Deployments/Services for all 7 components, Ingress, HPA
(web + aggregator), ConfigMap/Secret, PVCs, optional ServiceMonitor, probes,
Prometheus scrape annotations. `scripts/deploy_kind.sh`.
- Files: `deploy/helm/omnitune/**`, `scripts/deploy_kind.sh`
- Verify: `helm lint` clean; renders **20 resources**, all pass `kubeconform` strict schema validation.

### Task 22 — CI/CD + architecture docs ✅
`.github/workflows/ci.yml` (core / wasm / backend / web / helm jobs + GHCR image
push on main); `docs/CLOUD_NATIVE.md`.
- Files: `.github/workflows/ci.yml`, `docs/CLOUD_NATIVE.md`, `README.md`
- Verify: all workflow/compose YAML parsed valid.

---

## Hardening pass (ready-to-run fixes found during verification)

- **Tray icons** — created `app/assets/app_icon.{png,ico}`, declared in `pubspec.yaml` (tray loaded missing assets and silently failed).
- **macOS entitlements** — added `network.client`, `files.user-selected.read-only`, `assets.music.read-only`, `disable-library-validation` to Debug + Release (sandbox blocked HTTP, file reads, and the FFI dylib).
- **widget_test.dart** — replaced the stale counter-template test (referenced deleted `MyApp`, broke `flutter test`) with real smoke tests.
- **FFI loader** — also searches the macOS `.app` `Contents/Frameworks`.
- **CORS** — `backend/internal/httpmw/cors.go` + wrapped both services, so the browser web app (`:3000`) can call the API (`:8000`/`:8001`). Verified `Access-Control-Allow-Origin: *` + `OPTIONS` → 204.

---

## Verification matrix

| Layer | Verified on Windows dev box | Needs the user's Mac |
|-------|------------------------------|----------------------|
| C++ core | build + `test_core` + symbol exports | — |
| Go backend | full round-trip: cache, JWT, sync, metrics, NATS, CORS (Docker) | — |
| WASM core | emscripten build → `.wasm`/`.js` | **in-browser audio output** |
| Web (Next.js) | `next build` + Docker image + served HTML 200 | UI click-through / WASM playback |
| Flutter app | code review only | **macOS/iOS/Android runtime** |
| Helm/K8s | `helm lint` + template + kubeconform | **live kind cluster** |
| Compose stack | 9 services healthy end-to-end | — |

## Outstanding / next steps
- **Stream proxy:** `/stream/{id}` redirects to Audius; for the browser, proxy the
  bytes through the aggregator (server-side fetch + CORS) to avoid CDN CORS issues.
- **MinIO integration:** provisioned as object storage; wire the aggregator to
  cache audio blobs via the S3 API.
- **WASM audio:** uses miniaudio's `ScriptProcessorNode` backend (deprecation
  warning only); optional upgrade to AudioWorklet.
- **Embedded album-art extraction** from tags (folder-convention art works today).
- **Git remote:** repo has no remote and changes were untracked — set one up so
  the Mac can `git pull` a complete, atomic state instead of relying on folder sync.
