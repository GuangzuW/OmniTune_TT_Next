# Mobile & Multi-platform Setup

The repo checks in only the **macOS** and **web** runners. Generate the rest and
wire the native C++ core per platform. All commands assume the Flutter SDK is
installed (you run these on your Mac).

## 0. Generate the runners (once)

```bash
scripts/setup_platforms.sh                      # windows,macos,linux,ios,android
# or a subset:
cd app && flutter create --platforms=ios,android .
```

## Desktop (Windows / macOS / Linux)

The core is a shared library loaded over FFI. The build scripts compile it and
bundle it next to the runner:

```bash
# macOS / Linux
scripts/build_desktop.sh macos      # or: linux

# Windows (PowerShell)
pwsh scripts/build_desktop.ps1
```
The FFI loader (`app/lib/audio_player_ffi.dart`) searches the executable dir and
common CMake output dirs, so `flutter run -d <platform>` from the repo root also
works once the core is built into `core/build/` — **except sandboxed macOS**,
which can only load the dylib from inside the `.app` bundle.

**macOS notes:**
- Entitlements already grant outbound network, user-selected file access, and
  `disable-library-validation` (needed to load the unsigned FFI dylib).
- `scripts/build_desktop.sh macos` copies `libTTPlayerCore.dylib` into
  `Contents/Frameworks` of the release `.app`; the loader finds it there.
- For sandboxed **debug** runs, either run the build script first, or add the
  core as a pod so Xcode bundles it automatically — in `app/macos/Podfile`
  (target 'Runner'): `pod 'TTPlayerCore', :path => '../../core'`, then
  `cd app/macos && pod install` (the same `core/TTPlayerCore.podspec` covers
  macOS). With the pod, switch the macOS branch of `_loadLibrary` to
  `DynamicLibrary.process()`.

## Android

The C++ core is compiled by the NDK via Gradle's `externalNativeBuild`, pointing
at the existing `core/CMakeLists.txt` (which has an `ANDROID` branch linking
`OpenSLES`/`log`). After `flutter create --platforms=android .`:

1. Edit **`app/android/app/build.gradle`** — inside the `android { ... }` block add:

   ```gradle
   android {
       // ... existing config ...
       externalNativeBuild {
           cmake {
               path "../../../core/CMakeLists.txt"
               version "3.22.1"
           }
       }
       defaultConfig {
           // ... existing config ...
           externalNativeBuild {
               cmake {
                   arguments "-DANDROID_STL=c++_shared"
                   cppFlags "-std=c++17"
               }
           }
           ndk {
               abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64'
           }
       }
   }
   ```

2. Gradle packages `libTTPlayerCore.so` into the APK automatically; the FFI
   loader opens it by name (`DynamicLibrary.open('libTTPlayerCore.so')`).

3. Build/run:
   ```bash
   cd app && flutter run -d android
   ```

> The desktop-only plugins (`tray_manager`, `window_manager`, `hotkey_manager`,
> `desktop_drop`) are already guarded behind `Platform.is{MacOS,Windows,Linux}`
> in `main.dart`, so the app compiles and runs on mobile without them.

## iOS

The core is compiled into the app as a CocoaPod (`core/TTPlayerCore.podspec`);
the FFI resolves symbols via `DynamicLibrary.process()`. After
`flutter create --platforms=ios .`:

1. Add to **`app/ios/Podfile`**, inside `target 'Runner' do`:
   ```ruby
   pod 'TTPlayerCore', :path => '../../core'
   ```
2. Install pods:
   ```bash
   cd app/ios && pod install
   ```
3. Open `app/ios/Runner.xcworkspace` once to set a signing team, then:
   ```bash
   cd app && flutter run -d ios
   ```

The podspec disables dead-code stripping / private-extern so the exported
`extern "C"` symbols survive into the app binary for `dlsym`. If a release build
strips them, add `-Wl,-all_load` to *Other Linker Flags* for the `TTPlayerCore`
pod target.

## Networking on mobile

The backend base URLs default to `http://localhost:8000/8001`. On a physical
device `localhost` is the device itself, and plain HTTP is restricted:
- Point the app at your machine/server with
  `flutter run --dart-define=AGGREGATOR_URL=http://<host>:8000 --dart-define=USERSYNC_URL=http://<host>:8001`
  (use your LAN IP, or a deployed HTTPS URL).
- **Android:** cleartext HTTP needs `android:usesCleartextTraffic="true"` in the
  `<application>` tag of `app/android/app/src/main/AndroidManifest.xml` (dev
  only — prefer HTTPS in production).
- **iOS:** App Transport Security blocks non-HTTPS; add an ATS exception in
  `app/ios/Runner/Info.plist` for development, or serve the backend over HTTPS.
Audius itself is HTTPS, so streaming works without exceptions.

## Background audio (mobile)

`background_audio.dart` already implements an `audio_service` handler with
play/pause/stop/seek/next/prev for lock-screen and notification controls.
Standard `audio_service` platform setup applies:
- **Android:** the manifest needs the `audio_service` `MediaButtonReceiver` and a
  foreground-service entry (see the `audio_service` README); the notification
  channel id is `com.omnitune.app.channel.audio`.
- **iOS:** enable the *Audio, AirPlay, and Picture in Picture* Background Mode in
  Xcode (Signing & Capabilities).
