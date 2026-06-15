# OmniTune — Cloud-Native Web Platform

This document describes the web + cloud-native extension of OmniTune: a Next.js
web client that runs the **same C++ audio core compiled to WebAssembly**, backed
by the Go microservices, packaged for Kubernetes with full observability and CI/CD.

## Tech stack

| Layer | Technology |
|-------|-----------|
| Web frontend | **Next.js 15** (App Router) · React 19 · TypeScript · Tailwind CSS |
| In-browser audio | **C++ core → WebAssembly** (Emscripten + Embind), miniaudio Web Audio backend |
| Backend | **Go** microservices (Gorilla Mux): aggregator + user-sync |
| Cache | **Redis** (Audius search results) |
| Database | **PostgreSQL** (users + cloud playlists) |
| Messaging | **NATS** (search/event stream, JetStream-ready) |
| Object storage | **MinIO** (S3-compatible; audio/object cache) |
| Observability | **Prometheus** (scrape `/metrics`) + **Grafana** |
| Packaging | **Docker** multi-stage images, **Helm** chart |
| Orchestration | **Kubernetes** (kind/minikube locally; portable to EKS/GKE/AKS) |
| CI/CD | **GitHub Actions** (build/test/validate + GHCR image push) |

## Architecture

```
                         ┌────────────── Browser ──────────────┐
                         │  Next.js UI  +  TTPlayerCore (WASM)   │
                         │  fetch() audio → MEMFS → miniaudio    │
                         └───────┬───────────────────┬──────────┘
                                 │ /search /stream    │ /auth /sync /playlists
                                 ▼                    ▼
        ┌────────────── Kubernetes (Helm release) ───────────────────┐
        │  Ingress (nginx)                                            │
        │    ├─ web (Next.js, HPA 2–6)                                │
        │    ├─ aggregator (Go, HPA 2–6) ──► Redis (cache)            │
        │    │        └─ publish "omnitune.search" ──► NATS           │
        │    │        └─ Audius API (host-resolved)                   │
        │    └─ user-sync (Go) ──► PostgreSQL (JWT auth + playlists)  │
        │  MinIO (S3)   Prometheus ◄─ /metrics   Grafana ◄─ Prometheus│
        └─────────────────────────────────────────────────────────────┘
```

### Why WASM for the web player
The desktop/mobile apps load the native `TTPlayerCore` shared library over Dart
FFI. The browser can't load native code, so the **same C++ sources** are compiled
to WebAssembly (`scripts/emsdk_build.sh`) and exposed via Embind
(`EMSCRIPTEN_BINDINGS` in `core/src/AudioPlayer.cpp`): `load/play/pause/seek/
getPosition/getDuration/isPlaying/setEqBandGain/setVolume`. miniaudio's Web Audio
backend drives output; audio bytes from the aggregator's stream proxy are written
into the Emscripten in-memory FS and played by path (`web/lib/wasmPlayer.ts`).
One audio engine, four targets (Windows/macOS/Linux/iOS/Android **and** web).

## Run it

### Local (docker-compose) — full stack
```bash
docker compose up -d --build
```
| Service | URL |
|---------|-----|
| Web app | http://localhost:3000 |
| Aggregator | http://localhost:8000 (`/search`, `/stream/{id}`, `/metrics`, `/health`) |
| User-sync | http://localhost:8001 (`/auth/*`, `/sync/playlist`, `/playlists`, `/metrics`) |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3001 (anonymous; admin/admin) |
| MinIO console | http://localhost:9001 (minioadmin/minioadmin) |
| NATS monitoring | http://localhost:8222 |

### Kubernetes (kind)
```bash
scripts/deploy_kind.sh          # build + load images, install ingress + Helm release
echo "127.0.0.1 omnitune.local" | sudo tee -a /etc/hosts
open http://omnitune.local
```
Or manually:
```bash
helm upgrade --install omni deploy/helm/omnitune \
  --set image.registry=ghcr.io/<you> --set image.tag=latest
```

## Observability
- Both Go services expose Prometheus metrics at `/metrics` (request count +
  latency histograms via `backend/internal/metrics`, plus Go runtime metrics).
- Compose ships Prometheus (scrape config in `deploy/observability/`) + Grafana
  with a pre-provisioned Prometheus datasource.
- On K8s, pods carry `prometheus.io/scrape` annotations; with the
  **kube-prometheus-stack** Operator installed, set `serviceMonitor.enabled=true`
  to create `ServiceMonitor`s.

## CI/CD
`.github/workflows/ci.yml` runs on every push/PR:
- **core** — CMake build + `test_core`
- **wasm** — Emscripten build, asserts `.wasm`/`.js` artifacts
- **backend** — `go build` + `go vet`
- **web** — `npm install` + `next build`
- **helm** — `helm lint` + `helm template` + `kubeconform` schema validation
- **images** (main only) — build & push `aggregator`/`user-sync`/`web` to GHCR

## Scaling & production notes
- HPAs autoscale `web` and `aggregator` on CPU (needs metrics-server).
- Swap in managed Redis/Postgres (set `redis.enabled=false`, etc., and point env
  at managed endpoints) for cloud deployments.
- `NEXT_PUBLIC_*` URLs are client-side; for non-localhost hosts rebuild the web
  image with build args or front everything behind the Ingress host.
- MinIO is provisioned as the object-storage layer for caching streamed audio
  (next integration step: aggregator writes/reads track blobs via the S3 API).
