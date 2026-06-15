# Verifying OmniTune on macOS — step by step

Work top-to-bottom. Each step is independent; do the ones you care about.
Assumes your Mac has: Xcode + CLT, CMake, Go, Flutter, Node 18+, Docker Desktop,
and (for K8s) `kind`, `kubectl`, `helm` (`brew install kind kubernetes-cli helm`).

```bash
git pull          # get the latest (incl. the CORS fix)
cd OmniTune_TT_Next
```

---

## 1. C++ audio core (native)

```bash
cmake -S core -B core/build
cmake --build core/build
./core/build/test_core
```
**Expect:** `libTTPlayerCore.dylib` + `test_core` in `core/build/`, and the test
prints `Test completed.` with no crash.

Optional sanity on the EQ/metadata symbols:
```bash
nm -gU core/build/libTTPlayerCore.dylib | grep -E 'AudioPlayer_(setVolume|setEqBandGain)|ScanResult_getTitle'
```
**Expect:** those symbols listed.

---

## 2. Backend + full cloud-native stack (Docker)

Start Docker Desktop, then:
```bash
docker compose up -d --build
docker compose ps          # all 9 services "Up"
```

Verify each piece:
```bash
# Health
curl -s localhost:8000/health ; echo
curl -s localhost:8001/health ; echo

# Audius search (live) — twice to see the Redis cache flip MISS→HIT
curl -s -D - -o /dev/null "localhost:8000/search?query=lofi" | grep -i x-cache
curl -s -D - -o /dev/null "localhost:8000/search?query=lofi" | grep -i x-cache

# Auth → real JWT (3 dot-separated parts), then a protected playlist round-trip
TOKEN=$(curl -s -XPOST localhost:8001/auth/register -d '{"username":"alice","password":"secret123"}' | sed -E 's/.*"token":"([^"]+)".*/\1/')
echo "token parts: $(echo $TOKEN | awk -F. '{print NF}')"   # expect 3
curl -s -XPOST localhost:8001/sync/playlist -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"Fav","tracks":[{"ref":"audius:1","title":"A","artist":"X","position":0}]}' ; echo
curl -s localhost:8001/playlists -H "Authorization: Bearer $TOKEN" ; echo
curl -s -o /dev/null -w "no-token=%{http_code}\n" localhost:8001/playlists   # expect 401

# CORS (what makes the browser app work)
curl -s -D - -o /dev/null localhost:8000/health | grep -i access-control-allow-origin
```
**Expect:** health `ok`; `X-Cache: MISS` then `HIT`; a 3-part token; `synced`
then the playlist JSON; `no-token=401`; and `Access-Control-Allow-Origin: *`.

Infra dashboards (open in a browser):
- Prometheus targets all **up**: http://localhost:9090/targets
- Grafana (Prometheus datasource pre-wired): http://localhost:3001 (admin/admin)
- MinIO console: http://localhost:9001 (minioadmin/minioadmin)
- NATS got the search event: `curl -s localhost:8222/varz | grep in_msgs` → `> 0`

---

## 3. Web app + WebAssembly audio (the headline)

The stack from step 2 already serves the web app.

1. Open **http://localhost:3000**.
2. Type a query (e.g. `lofi`) → **Search**. You should see results with artwork.
3. **Click a track.** First play fetches the WASM core (~0.5 MB) then plays.
   - Open DevTools → Network: you'll see `/wasm/TTPlayerCore.js` + `.wasm` load,
     and a `stream/<id>` fetch.
   - Console should be free of CORS errors (the fix in step 2).
4. Test transport: play/pause, seek, **volume**, **prev/next**, and the **EQ**
   panel (sliders + presets) — all driven by the C++ core running in the browser.
5. Cloud: **Login**/**Register** (top-right), **↑ Cloud** to save the queue,
   **↓ Cloud** to load it back.

**Expect:** audible playback in the browser via the WASM core; EQ changes are
audible; cloud save/load works.

> If a specific track won't play, it's usually that Audius CDN host's CORS on the
> audio bytes — try another track. Playback requires the initial click (browser
> autoplay policy), which the UI satisfies.

Dev mode alternative (hot reload):
```bash
cd web && cp .env.example .env.local && npm install && npm run dev   # http://localhost:3000
```

---

## 4. Flutter desktop (macOS)

```bash
cd app && flutter pub get && cd ..
cmake -S core -B core/build && cmake --build core/build   # if not already
./scripts/build_desktop.sh macos
open app/build/macos/Build/Products/Release/*.app
```
`build_desktop.sh` bundles `libTTPlayerCore.dylib` into the `.app`'s
`Contents/Frameworks` so the sandbox can load it; the entitlements already allow
network + user-selected files + the unsigned dylib.

**Verify in the app:** "Add folder" → pick a folder of MP3/FLAC → tracks appear
with **real title/artist/duration**; play; **EQ** changes the sound; **next/prev**
and the system **tray** menu work; the **Online (Audius)** panel searches/streams;
cloud login + sync work.

> Quick UI-only check with hot reload: `flutter run -d macos` from the **repo root**.
> The app launches even if the core isn't bundled (status bar shows "core not
> loaded"); for audio in dev, use the build script above or add the pod (see
> `docs/MOBILE_SETUP.md` → macOS notes).

---

## 5. Flutter mobile (optional)

Follow `docs/MOBILE_SETUP.md`:
```bash
scripts/setup_platforms.sh ios,android
# Android: add the externalNativeBuild block → flutter run -d <android>
# iOS: add the pod + pod install → open Runner.xcworkspace (set team) → flutter run -d <ios>
```
Point the app at your machine for the backend:
```bash
flutter run -d <device> \
  --dart-define=AGGREGATOR_URL=http://<your-LAN-ip>:8000 \
  --dart-define=USERSYNC_URL=http://<your-LAN-ip>:8001
```

---

## 6. Kubernetes (kind)

```bash
./scripts/deploy_kind.sh
kubectl get pods                      # all Running
echo "127.0.0.1 omnitune.local" | sudo tee -a /etc/hosts
open http://omnitune.local
```
Validate manifests without a cluster:
```bash
helm lint deploy/helm/omnitune
helm template omni deploy/helm/omnitune | kubectl apply --dry-run=client -f -
```
**Expect:** lint clean; ~20 resources render and pass dry-run.

---

## 7. WASM core rebuild (optional)

```bash
docker run --rm -v "$PWD:/src" -w /src emscripten/emsdk:latest ./scripts/emsdk_build.sh
cp core/build_wasm/TTPlayerCore.{js,wasm} web/public/wasm/
```
**Expect:** fresh `TTPlayerCore.wasm` (~0.45 MB) + `.js`.

---

## Teardown
```bash
docker compose down            # or: down -v to also drop volumes
kind delete cluster --name omnitune
```

## What was verified on the Windows dev box (so you can focus elsewhere)
C++ core build/test + symbol exports · Go build + full backend round-trip (cache,
JWT, sync, metrics, NATS, CORS) · `next build` · WASM build · `helm lint`/template
+ kubeconform · full `docker compose` stack health. **Not** verifiable there and
worth your attention: in-browser WASM **audio output**, the Flutter macOS/iOS/
Android **runtime**, and a live **kind** cluster.
