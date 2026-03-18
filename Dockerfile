# Multi-stage build for OmniTune TT Next Core
FROM emscripten/emsdk:latest AS wasm-build
WORKDIR /src
COPY . .
RUN chmod +x scripts/emsdk_build.sh && ./scripts/emsdk_build.sh

FROM alpine:latest
WORKDIR /app
COPY --from=wasm-build /src/core/build_wasm/TTPlayerCore.js .
COPY --from=wasm-build /src/core/build_wasm/TTPlayerCore.wasm .
COPY --from=wasm-build /src/core/build_wasm/index.html .

EXPOSE 8080
CMD ["npx", "serve", "-p", "8080"]
