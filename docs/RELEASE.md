# Release & Packaging

Producing installable, production builds of the OmniTune app. Run on a machine
with the Flutter SDK (your Mac for Apple targets).

## 0. One-time per machine
```bash
scripts/setup_platforms.sh                 # generate windows/linux/ios/android runners
cd app && flutter pub get
dart run flutter_launcher_icons            # app icons for every platform (assets/icon.png)
dart run flutter_native_splash:create      # branded splash (#252C38)
```

## Desktop
```bash
# Build the native C++ core, then the app, and bundle the lib (see scripts):
scripts/build_desktop.sh macos             # → app/build/macos/Build/Products/Release/*.app
scripts/build_desktop.sh linux             # → app/build/linux/x64/release/bundle
pwsh scripts/build_desktop.ps1             # Windows → app/build/windows/x64/runner/Release
```
- **macOS .dmg:** `brew install create-dmg` then
  `create-dmg OmniTune.dmg app/build/macos/Build/Products/Release/omnitune.app`.
- **Windows installer (.msix):** add `msix` dev dep + config, then `dart run msix:create`.
  (Or package the `Release/` folder with Inno Setup.)

## Mobile
Wire the native core first (see `docs/MOBILE_SETUP.md`): Android NDK
`externalNativeBuild`, iOS `TTPlayerCore.podspec`.
```bash
# Android
cd app && flutter build apk --release          # or: appbundle (Play Store)
# iOS (on macOS, signing team set in Xcode)
flutter build ipa --release
```
Point release builds at your deployed backend:
```bash
flutter build <target> --release \
  --dart-define=AGGREGATOR_URL=https://api.yourhost \
  --dart-define=USERSYNC_URL=https://sync.yourhost
```

## CI
`.github/workflows/ci.yml` runs `flutter analyze` + `flutter test` on every push,
and a **macOS build job** compiles the core + `flutter build macos` (the macOS
runner is checked in). Add build jobs for the other platforms once their runners
are generated and committed.

## Pre-flight checklist
- [ ] `flutter analyze` clean, `flutter test` green
- [ ] App icon + splash generated for each target
- [ ] Backend URLs point at production (`--dart-define`)
- [ ] macOS entitlements allow network + the FFI dylib (already set)
- [ ] Android: `usesCleartextTraffic` only if backend is plain HTTP (prefer HTTPS)
- [ ] Bump `version:` in `app/pubspec.yaml`
