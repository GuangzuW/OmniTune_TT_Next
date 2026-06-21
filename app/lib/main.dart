import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:app/core/router/app_router.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/data/services/audio_player_ffi.dart';
import 'package:app/data/services/background_audio.dart';
import 'package:app/data/services/tray_service.dart';
import 'package:app/state/player_controller.dart';
import 'package:app/state/providers.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_isDesktop) {
    await windowManager.ensureInitialized();
    const opts = WindowOptions(
      size: Size(1180, 760),
      minimumSize: Size(900, 600),
      center: true,
      title: 'OmniTune',
    );
    windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    await hotKeyManager.unregisterAll();
  }

  // Initialize the native engine + OS media handler once; tolerate failure so
  // the UI still runs if the core is missing.
  AudioPlayerFFI? engine;
  BackgroundAudioHandler? handler;
  if (!kIsWeb) {
    try {
      engine = AudioPlayerFFI();
      handler = await AudioService.init(
        builder: () => BackgroundAudioHandler(engine!),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.omnitune.app.channel.audio',
          androidNotificationChannelName: 'Music Playback',
          androidNotificationOngoing: true,
        ),
      );
    } catch (e) {
      debugPrint('Audio engine init failed: $e');
    }
  }

  final container = ProviderContainer(overrides: [
    audioEngineProvider.overrideWithValue(engine),
    audioHandlerProvider.overrideWithValue(handler),
  ]);

  if (_isDesktop) {
    final player = container.read(playerControllerProvider.notifier);
    try {
      final tray = TrayService(
        onPlayPause: player.togglePlay,
        onNext: () => player.next(),
        onPrev: player.prev,
        onQuit: () => exit(0),
      );
      await tray.init();
    } catch (e) {
      debugPrint('Tray init failed: $e');
    }
    await _registerHotkeys(player);
  }

  runApp(UncontrolledProviderScope(container: container, child: const OmniTuneApp()));
}

Future<void> _registerHotkeys(PlayerController player) async {
  Future<void> reg(KeyCode code, VoidCallback fn) => hotKeyManager.register(
        HotKey(code, modifiers: [KeyModifier.alt], scope: HotKeyScope.system),
        keyDownHandler: (_) => fn(),
      );
  try {
    await reg(KeyCode.keyP, player.togglePlay);
    await reg(KeyCode.keyS, player.stop);
    await reg(KeyCode.arrowRight, () => player.next());
    await reg(KeyCode.arrowLeft, player.prev);
  } catch (e) {
    debugPrint('Hotkey registration failed: $e');
  }
}

class OmniTuneApp extends StatelessWidget {
  const OmniTuneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OmniTune',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
